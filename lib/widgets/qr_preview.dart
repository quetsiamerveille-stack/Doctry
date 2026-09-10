import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/api_client.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/file_saver.dart';
import '../models/document.dart';
import '../providers/workspace_provider.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class QrPreview extends StatelessWidget {
  const QrPreview({super.key, required this.document, this.size = 230, this.onDownloaded});

  final DocRecord document;
  final double size;
  final ValueChanged<String>? onDownloaded;

  Future<void> _download(BuildContext context) async {
    final List<int>? bytes =
        await context.read<WorkspaceProvider>().qrBytes(document.qrUrl);
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        showDoctrySnackBar(context, 'Impossible de récupérer le QR Code.', isError: true);
      }
      return;
    }
    final String name = 'DOCTRY-${document.qrId}.png';
    final String path = await saveBytes(Uint8List.fromList(bytes), name);
    if (context.mounted) {
      showDoctrySnackBar(context, 'QR Code téléchargé : $path');
      onDownloaded?.call(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Column(
            children: <Widget>[
              Image.network(
                ApiClient.instance.mediaUrl(document.qrUrl),
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => SizedBox(
                  width: size,
                  height: size,
                  child: const Center(
                    child: Icon(Icons.qr_code_2, size: 90, color: AppColors.grey),
                  ),
                ),
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
                  if (progress == null) {
                    return child;
                  }
                  return SizedBox(
                    width: size,
                    height: size,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                document.qrId,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DoctryButton(
          label: 'Télécharger le QR Code',
          icon: Icons.download_outlined,
          variant: DoctryButtonVariant.gold,
          onPressed: () => _download(context),
        ),
      ],
    );
  }
}

