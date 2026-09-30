import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/formatters.dart';

/// Lee con la cámara el código QR del folio que genera el panel del médico.
/// Devuelve el folio normalizado ("CM26-9HTK57") o null si se cancela.
class FolioScannerScreen extends StatefulWidget {
  const FolioScannerScreen({super.key});

  @override
  State<FolioScannerScreen> createState() => _FolioScannerScreenState();
}

class _FolioScannerScreenState extends State<FolioScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final folio = folioFromQr(barcode.rawValue ?? '');
      if (folio != null && folioPattern.hasMatch(folio)) {
        _done = true;
        Navigator.pop(context, folio);
        return;
      }
    }
    if (!_invalid) setState(() => _invalid = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear folio'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              _invalid
                  ? 'Ese código no es un folio de NeuroVoice. Usa el QR que te dio tu médico.'
                  : 'Apunta la cámara al código QR que te dio tu médico.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;

  const _ScannerError({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Permite el acceso a la cámara para escanear el código.'
                    : 'No se pudo abrir la cámara. Escribe el folio a mano.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (denied) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: openAppSettings,
                  child: const Text('Abrir ajustes'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
