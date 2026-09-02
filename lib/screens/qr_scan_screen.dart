import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// صفحه‌ی اسکن QR Code برای افزودن سریع یه سرور، بدون نیاز به کپی/پیست
/// دستی لینک. اولین QR معتبر (شروع‌شده با یکی از پروتکل‌های پشتیبانی‌شده)
/// که پیدا بشه، به صفحه‌ی قبل برگردونده میشه.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  static final _validPrefixes = ['vmess://', 'vless://', 'trojan://', 'ss://'];

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      if (_validPrefixes.any((p) => value.startsWith(p))) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اسکن QR سرور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'فلاش',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(14),
              child: const Text(
                'دوربین رو روی QR کانفیگ سرور بگیر',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}