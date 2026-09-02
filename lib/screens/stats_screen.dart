import 'package:flutter/material.dart';
import '../models/vpn_server.dart';

/// صفحه‌ی آمار مصرف ترافیک به‌تفکیک سرور. عددها تقریبی‌ان (از روی
/// سرعت لحظه‌ای در طول اتصال جمع می‌زنیم)، ولی برای مقایسه‌ی کلی مصرف
/// بین سرورها کافیه.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.servers});

  final List<VpnServer> servers;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '۰ B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final totalUp = servers.fold<int>(0, (sum, s) => sum + s.totalUploadBytes);
    final totalDown = servers.fold<int>(0, (sum, s) => sum + s.totalDownloadBytes);
    final sorted = [...servers]
      ..sort((a, b) => (b.totalUploadBytes + b.totalDownloadBytes)
          .compareTo(a.totalUploadBytes + a.totalDownloadBytes));

    return Scaffold(
      appBar: AppBar(title: const Text('آمار مصرف ترافیک')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: _totalTile(context, 'کل آپلود', _formatBytes(totalUp), Icons.arrow_upward),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _totalTile(context, 'کل دانلود', _formatBytes(totalDown), Icons.arrow_downward),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('به‌تفکیک سرور', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          if (sorted.isEmpty || totalUp + totalDown == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('هنوز مصرفی ثبت نشده', style: TextStyle(color: Colors.black45))),
            )
          else
            ...sorted.map(
              (s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(s.remark),
                  subtitle: Text(
                    'آپلود ${_formatBytes(s.totalUploadBytes)}   •   دانلود ${_formatBytes(s.totalDownloadBytes)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalTile(BuildContext context, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12)),
      ],
    );
  }
}