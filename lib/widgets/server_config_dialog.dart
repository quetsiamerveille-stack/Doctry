import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/api_config.dart';
import '../core/services/api_client.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

Future<void> showServerConfigDialog(BuildContext context) async {
  final AuthProvider auth = context.read<AuthProvider>();
  final TextEditingController controller =
      TextEditingController(text: ApiConfig.baseUrl);

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      String? status;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Serveur DOCTRY'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Adresse du backend FastAPI utilisé par l\'application.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL du serveur',
                      hintText: 'http://127.0.0.1:8000',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.radar_outlined, size: 15, color: AppColors.siam),
                        label: const Text('Détecter automatiquement',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.siam)),
                        onPressed: () async {
                          setState(() => status = 'Recherche d\'un serveur DOCTRY actif...');
                          final String? found = await ApiConfig.probeAndAutoSelect();
                          if (found != null) {
                            controller.text = found;
                            await auth.refreshServerInfo();
                            setState(() {
                              status = 'Serveur DOCTRY détecté sur $found !';
                            });
                          } else {
                            setState(() {
                              status = 'Aucun serveur DOCTRY trouvé sur les ports 8000/8001.';
                            });
                          }
                        },
                      ),
                      for (final String preset in _presets())
                        ActionChip(
                          label: Text(preset, style: const TextStyle(fontSize: 11)),
                          onPressed: () => setState(() {
                            controller.text = preset;
                            status = null;
                          }),
                        ),
                    ],
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      status!,
                      style: TextStyle(
                        fontSize: 12,
                        color: (status!.contains('joignable') || status!.contains('détecté'))
                            ? AppColors.green
                            : AppColors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await ApiConfig.reset();
                  controller.text = ApiConfig.baseUrl;
                  await auth.refreshServerInfo();
                  if (context.mounted) {
                    auth.clearMessages();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Réinitialiser'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fermer'),
              ),
              FilledButton(
                onPressed: () async {
                  final String url = controller.text.trim();
                  if (url.isEmpty) {
                    setState(() => status = 'Saisissez une adresse valide.');
                    return;
                  }
                  await ApiConfig.override(url);
                  ApiClient.instance.setToken(null);
                  await auth.refreshServerInfo();
                  setState(() {
                    status = auth.server.online
                        ? 'Serveur joignable : ${auth.server.aiEngine}.'
                        : 'Serveur injoignable. Démarrez le backend FastAPI.';
                  });
                  controller.text = ApiConfig.baseUrl;
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

List<String> _presets() {
  return <String>[
    'http://127.0.0.1:8000',
    'http://127.0.0.1:8001',
    'http://localhost:8000',
    'http://localhost:8001',
    'http://10.0.2.2:8000',
    'http://10.0.2.2:8001',
  ];
}
