import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:uuid/uuid.dart';

import '../models/vpn_server.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _uuid = const Uuid();

  late final FlutterV2ray _v2ray = FlutterV2ray(
    onStatusChanged: (status) {
      setState(() => _status = status);
    },
  );

  List<VpnServer> _servers = [];
  String? _connectedServerId;
  V2RayStatus _status = V2RayStatus();
  bool _isInitialized = false;
  // روی وب، پلاگین flutter_v2ray پشتیبانی نمیشه (کاناله نیتیو نداره)
  // پس اتصال VPN واقعی رو غیرفعال می‌کنیم ولی اپ رو گیر نمی‌ندازیم.
  bool _vpnUnsupported = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!kIsWeb) {
      try {
        await _v2ray.initializeV2Ray();
      } catch (e) {
        // اگه مقداردهی نیتیو با خطا مواجه شد، اپ رو گیر ندازیم؛
        // فقط قابلیت اتصال رو غیرفعال می‌کنیم.
        _vpnUnsupported = true;
      }
    } else {
      _vpnUnsupported = true;
    }

    final servers = await _storage.loadServers();
    if (!mounted) return;
    setState(() {
      _servers = servers;
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    // اگه اتصال برقراره، موقع بستن صفحه قطعش نمی‌کنیم؛ VpnService خودش
    // در پس‌زمینه به کارش ادامه میده (رفتار طبیعی یه اپ VPN).
    super.dispose();
  }

  // --- افزودن سرور از طریق لینک اشتراک (تکی یا گروهی) ---

  /// یک تکه متن که ممکنه شامل چند لینک کانفیگ باشه رو (چه با خط جدید از هم
  /// جدا شده باشن، چه بدون هیچ جداکننده‌ای به هم چسبیده باشن) به لینک‌های
  /// مستقل می‌شکونه. ملاک شکستن، شروع هر پروتکل پشتیبانی‌شده‌ست
  /// (vmess:// | vless:// | trojan:// | ss://).
  List<String> _splitConfigBlob(String input) {
    // بعضی اپ‌ها بین کانفیگ‌ها یه کاراکتر نامرئی (Object Replacement Character)
    // می‌ذارن؛ اون رو با خط جدید عوض می‌کنیم که تمیزتر جدا بشه.
    final cleaned = input.replaceAll('\uFFFC', '\n');

    final starts = RegExp(r'(?=(?:vmess|vless|trojan|ss)://)')
        .allMatches(cleaned)
        .map((m) => m.start)
        .toList();

    if (starts.isEmpty) {
      final trimmed = cleaned.trim();
      return trimmed.isEmpty ? [] : [trimmed];
    }

    final parts = <String>[];
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : cleaned.length;
      final part = cleaned.substring(starts[i], end).trim();
      if (part.isNotEmpty) parts.add(part);
    }
    return parts;
  }

  Future<void> _showAddServerDialog() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن سرور (تکی یا گروهی)'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText:
                'یک یا چند لینک (vmess://, vless://, trojan://, ss://) رو پیست کن؛ لازم نیست خودت جداشون کنی.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );

    if (input == null || input.trim().isEmpty) return;

    final chunks = _splitConfigBlob(input);
    var added = 0;
    var failed = 0;

    for (final chunk in chunks) {
      try {
        final parsed = FlutterV2ray.parseFromURL(chunk);
        _servers.add(
          VpnServer(
            id: _uuid.v4(),
            remark: parsed.remark.isNotEmpty ? parsed.remark : 'سرور بدون‌نام',
            rawLink: chunk,
          ),
        );
        added++;
      } catch (_) {
        failed++;
      }
    }

    if (added > 0) {
      setState(() {});
      await _storage.saveServers(_servers);
    }

    if (!mounted) return;
    _showError(
      failed == 0
          ? '$added سرور با موفقیت اضافه شد.'
          : '$added سرور اضافه شد، $failed موردش فرمت پشتیبانی‌شده نداشت.',
    );
  }

  Future<void> _deleteServer(VpnServer server) async {
    if (_connectedServerId == server.id) {
      await _disconnect();
    }
    setState(() => _servers.removeWhere((s) => s.id == server.id));
    await _storage.saveServers(_servers);
  }

  Future<void> _testPing(VpnServer server) async {
    if (_vpnUnsupported) {
      _showError('تست پینگ روی این پلتفرم پشتیبانی نمیشه.');
      return;
    }
    try {
      final parsed = FlutterV2ray.parseFromURL(server.rawLink);
      final delay = await _v2ray.getServerDelay(
        config: parsed.getFullConfiguration(),
      );
      setState(() => server.lastPingMs = delay);
    } catch (e) {
      _showError('تست پینگ ناموفق بود.\n$e');
    }
  }

  Future<void> _connect(VpnServer server) async {
    if (_vpnUnsupported) {
      _showError(
        kIsWeb
            ? 'اتصال VPN روی نسخه‌ی وب پشتیبانی نمیشه. لطفاً از اپ Android/iOS/Desktop استفاده کن.'
            : 'مقداردهی V2Ray روی این دستگاه با خطا مواجه شد.',
      );
      return;
    }
    try {
      final parsed = FlutterV2ray.parseFromURL(server.rawLink);

      final hasPermission = await _v2ray.requestPermission();
      if (!hasPermission) {
        _showError('برای اتصال، باید مجوز VPN رو تأیید کنی.');
        return;
      }

      await _v2ray.startV2Ray(
        remark: parsed.remark,
        config: parsed.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      setState(() => _connectedServerId = server.id);
    } catch (e) {
      _showError('اتصال ناموفق بود.\n$e');
    }
  }

  Future<void> _disconnect() async {
    await _v2ray.stopV2Ray();
    setState(() => _connectedServerId = null);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AY-Tunnel')),
      body: Column(
        children: [
          if (_vpnUnsupported) _buildUnsupportedBanner(),
          _buildStatusCard(),
          Expanded(
            child: _servers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 40, color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
                        const SizedBox(height: 10),
                        const Text(
                          'هنوز سروری اضافه نکردی',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _servers.length,
                    itemBuilder: (ctx, i) => _buildServerTile(_servers[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServerDialog,
        icon: const Icon(Icons.add),
        label: const Text('افزودن سرور'),
      ),
    );
  }

  Widget _buildUnsupportedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              kIsWeb
                  ? 'نسخه‌ی وب فقط برای مدیریت لیست سرورهاست؛ اتصال واقعی VPN رو باید از اپ موبایل/دسکتاپ انجام بدی.'
                  : 'اتصال V2Ray روی این دستگاه در دسترس نیست.',
              style: const TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _connectedServerId != null;
    final scheme = Theme.of(context).colorScheme;
    final accent = isConnected ? const Color(0xFF2E7D32) : scheme.primary;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isConnected
                ? [const Color(0xFFE8F7EC), const Color(0xFFF4FBF6)]
                : [scheme.primary.withOpacity(0.08), Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.12),
              ),
              child: Icon(
                isConnected ? Icons.shield : Icons.shield_outlined,
                color: accent,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'متصل' : 'قطع',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 6),
                    Text(
                      'آپلود ${_status.uploadSpeed} B/s   •   دانلود ${_status.downloadSpeed} B/s',
                      style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                    Text(
                      'مدت اتصال: ${_status.duration}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerTile(VpnServer server) {
    final isConnected = _connectedServerId == server.id;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected
                ? const Color(0xFF2E7D32).withOpacity(0.12)
                : scheme.primary.withOpacity(0.10),
          ),
          child: Icon(
            isConnected ? Icons.check_circle : Icons.dns_outlined,
            color: isConnected ? const Color(0xFF2E7D32) : scheme.primary,
          ),
        ),
        title: Text(
          server.remark,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          server.lastPingMs != null ? '${server.lastPingMs} ms' : 'تست‌نشده',
          style: const TextStyle(color: Colors.black45, fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.speed, color: scheme.primary),
              tooltip: 'تست پینگ',
              onPressed: () => _testPing(server),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'حذف',
              onPressed: () => _deleteServer(server),
            ),
          ],
        ),
        onTap: () => isConnected ? _disconnect() : _connect(server),
      ),
    );
  }
}