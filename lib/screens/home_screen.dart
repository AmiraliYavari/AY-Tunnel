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

  // --- افزودن سرور از طریق لینک اشتراک ---
  Future<void> _showAddServerDialog() async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن سرور جدید'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'لینک را اینجا پیست کنید (vmess://, vless://, trojan://, ss://)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );

    if (link == null || link.isEmpty) return;

    try {
      final parsed = FlutterV2ray.parseFromURL(link);
      final newServer = VpnServer(
        id: _uuid.v4(),
        remark: parsed.remark.isNotEmpty ? parsed.remark : 'سرور بدون‌نام',
        rawLink: link,
      );
      setState(() => _servers.add(newServer));
      await _storage.saveServers(_servers);
    } catch (e) {
      if (!mounted) return;
      _showError('لینک نامعتبره یا فرمتش پشتیبانی نمیشه.\n$e');
    }
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
      appBar: AppBar(title: const Text('کلاینت V2Ray من')),
      body: Column(
        children: [
          if (_vpnUnsupported) _buildUnsupportedBanner(),
          _buildStatusCard(),
          Expanded(
            child: _servers.isEmpty
                ? const Center(child: Text('هنوز سروری اضافه نکردی'))
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
      color: Colors.orange.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        kIsWeb
            ? 'نسخه‌ی وب فقط برای مدیریت لیست سرورهاست؛ اتصال واقعی VPN رو باید از اپ موبایل/دسکتاپ انجام بدی.'
            : 'اتصال V2Ray روی این دستگاه در دسترس نیست.',
        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _connectedServerId != null;
    return Card(
      margin: const EdgeInsets.all(12),
      color: isConnected
          ? Colors.green.withOpacity(0.15)
          : Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConnected ? 'متصل' : 'قطع',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isConnected ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (isConnected) ...[
              const SizedBox(height: 8),
              Text('آپلود: ${_status.uploadSpeed} B/s'),
              Text('دانلود: ${_status.downloadSpeed} B/s'),
              Text('مدت اتصال: ${_status.duration}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerTile(VpnServer server) {
    final isConnected = _connectedServerId == server.id;
    return ListTile(
      leading: Icon(
        isConnected ? Icons.check_circle : Icons.dns_outlined,
        color: isConnected ? Colors.green : null,
      ),
      title: Text(server.remark),
      subtitle: Text(
        server.lastPingMs != null ? '${server.lastPingMs} ms' : 'تست‌نشده',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'تست پینگ',
            onPressed: () => _testPing(server),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف',
            onPressed: () => _deleteServer(server),
          ),
        ],
      ),
      onTap: () => isConnected ? _disconnect() : _connect(server),
    );
  }
}