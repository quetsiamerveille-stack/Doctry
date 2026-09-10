import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.title = 'Scanner le QR Code'});

  final String title;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final TextEditingController _manual = TextEditingController();
  bool _settled = false;
  String? _error;
  bool _cameraFailed = false;

  @override
  void dispose() {
    _manual.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String? payload) {
    final String value = (payload ?? '').trim();
    if (value.isEmpty || _settled) {
      return;
    }
    _settled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        foregroundColor: AppColors.white,
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Lampe torche',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Changer de caméra',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (_cameraFailed)
                    Container(
                      color: AppColors.darkBlue,
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Caméra indisponible. Saisissez le contenu du QR Code '
                            'dans le champ ci-dessous.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.white, fontSize: 13.5),
                          ),
                        ),
                      ),
                    )
                  else
                    MobileScanner(
                      controller: _controller,
                      onDetect: (BarcodeCapture capture) {
                        for (final Barcode barcode in capture.barcodes) {
                          if ((barcode.rawValue ?? '').isNotEmpty) {
                            _submit(barcode.rawValue);
                            return;
                          }
                        }
                      },
                      errorBuilder: (BuildContext context, MobileScannerException error) {
                        _cameraFailed = true;
                        return Container(
                          color: AppColors.darkBlue,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Caméra indisponible : ${error.errorDetails?.message ?? error.errorCode.name}. '
                                'Saisissez le contenu du QR Code dans le champ ci-dessous.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.white, fontSize: 13),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Center(
                    child: Container(
                      height: 240,
                      width: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gold, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Placez le QR Code DOCTRY dans le cadre doré.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manual,
                    decoration: const InputDecoration(
                      labelText: 'Contenu du QR Code (saisie manuelle)',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: _submit,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.darkBlue,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.siam,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: () {
                            if (_manual.text.trim().isEmpty) {
                              setState(() => _error = 'Le contenu est vide.');
                              return;
                            }
                            _submit(_manual.text);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Valider'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> openQrScanner(BuildContext context, {String title = 'Scanner le QR Code'}) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute<String>(
      builder: (_) => QrScannerScreen(title: title),
    ),
  );
}
