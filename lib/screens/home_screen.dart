import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:uuid/uuid.dart';

import '../models/vpn_server.dart';
import '../services/storage_service.dart';
import '../utils/config_parser.dart';
import 'qr_scan_screen.dart';
import 'stats_screen.dart';
import 'subscriptions_screen.dart';

enum _SortMode { favoriteFirst, byPing, byName }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _uuid = const Uuid();

  late final FlutterV2ray _v2ray = FlutterV2ray(
    onStatusChanged: _onStatusChanged,
  );

  List<VpnServer> _servers = [];
  String? _connectedServerId;
  V2RayStatus _status = V2RayStatus();
  bool _isInitialized = false;
  _SortMode _sortMode = _SortMode.favoriteFirst;

  // روی وب، پلاگین flutter_v2ray پشتیبانی نمیشه (کاناله نیتیو نداره)
  // پس اتصال VPN واقعی رو غیرفعال می‌کنیم ولی اپ رو گیر نمی‌ندازیم.
  bool _vpnUnsupported = false;

  // شمارنده‌ی تقریبی مصرف نشست جاری؛ چون onStatusChanged هر ثانیه صدا زده
  // میشه، سرعت لحظه‌ای رو تقریباً معادل بایت مصرف‌شده‌ی همون ثانیه در نظر
  // می‌گیریم و موقع قطع اتصال، روی مجموع سرور ذخیره می‌کنیم.
  int _sessionUploadBytes = 0;
  int _sessionDownloadBytes = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _onStatusChanged(V2RayStatus status) {
    if (_connectedServerId != null) {
      _sessionUploadBytes += status.uploadSpeed;
      _sessionDownloadBytes += status.downloadSpeed;
    }
    setState(() => _status = status);
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
    await _addRawLinks(splitConfigBlob(input));
  }

  Future<void> _scanQr() async {
    final link = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (link == null) return;
    await _addRawLinks([link]);
  }

  /// چند لینک خام رو پارس و به لیست سرورها اضافه می‌کنه؛ در پایان یه
  /// خلاصه (تعداد موفق/ناموفق) نشون میده.
  Future<void> _addRawLinks(List<String> links, {String? groupTag}) async {
    var added = 0;
    var failed = 0;
    for (final link in links) {
      try {
        final parsed = FlutterV2ray.parseFromURL(link);
        _servers.add(
          VpnServer(
            id: _uuid.v4(),
            remark: parsed.remark.isNotEmpty ? parsed.remark : 'سرور بدون‌نام',
            rawLink: link,
            groupTag: groupTag,
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
    _showInfo(
      failed == 0
          ? '$added سرور با موفقیت اضافه شد.'
          : '$added سرور اضافه شد، $failed موردش فرمت پشتیبانی‌شده نداشت.',
    );
  }

  /// وقتی یه سابسکریپشن به‌روزرسانی میشه، سرورهای قدیمی همون گروه حذف و
  /// نسخه‌ی تازه جایگزین میشه (تا سرورهای منقضی‌شده توی لیست نمونن).
  Future<void> _replaceGroupServers(String groupTag, List<String> rawLinks) async {
    _servers.removeWhere((s) => s.groupTag == groupTag);
    var added = 0;
    for (final link in rawLinks) {
      try {
        final parsed = FlutterV2ray.parseFromURL(link);
        _servers.add(
          VpnServer(
            id: _uuid.v4(),
            remark: parsed.remark.isNotEmpty ? parsed.remark : 'سرور بدون‌نام',
            rawLink: link,
            groupTag: groupTag,
          ),
        );
        added++;
      } catch (_) {
        // کانفیگ‌های نامعتبر داخل سابسکریپشن رو نادیده می‌گیریم.
      }
    }
    setState(() {});
    await _storage.saveServers(_servers);
    if (added == 0) {
      throw Exception('هیچ‌کدوم از کانفیگ‌های این سابسکریپشن معتبر نبودن.');
    }
  }

  Future<void> _deleteServer(VpnServer server) async {
    if (_connectedServerId == server.id) {
      await _disconnect();
    }
    setState(() => _servers.removeWhere((s) => s.id == server.id));
    await _storage.saveServers(_servers);
  }

  Future<void> _toggleFavorite(VpnServer server) async {
    setState(() => server.isFavorite = !server.isFavorite);
    await _storage.saveServers(_servers);
  }

  Future<void> _testPing(VpnServer server) async {
    if (_vpnUnsupported) {
      _showInfo('تست پینگ روی این پلتفرم پشتیبانی نمیشه.');
      return;
    }
    try {
      final parsed = FlutterV2ray.parseFromURL(server.rawLink);
      final delay = await _v2ray.getServerDelay(
        config: parsed.getFullConfiguration(),
      );
      setState(() => server.lastPingMs = delay);
      await _storage.saveServers(_servers);
    } catch (e) {
      _showInfo('تست پینگ ناموفق بود.\n$e');
    }
  }

  Future<void> _connect(VpnServer server) async {
    if (_vpnUnsupported) {
      _showInfo(
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
        _showInfo('برای اتصال، باید مجوز VPN رو تأیید کنی.');
        return;
      }

      await _v2ray.startV2Ray(
        remark: parsed.remark,
        config: parsed.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      _sessionUploadBytes = 0;
      _sessionDownloadBytes = 0;
      setState(() => _connectedServerId = server.id);
    } catch (e) {
      _showInfo('اتصال ناموفق بود.\n$e');
    }
  }

  Future<void> _disconnect() async {
    await _v2ray.stopV2Ray();
    final connectedId = _connectedServerId;
    if (connectedId != null) {
      final server = _servers.where((s) => s.id == connectedId).firstOrNull;
      if (server != null) {
        server.totalUploadBytes += _sessionUploadBytes;
        server.totalDownloadBytes += _sessionDownloadBytes;
        await _storage.saveServers(_servers);
      }
    }
    _sessionUploadBytes = 0;
    _sessionDownloadBytes = 0;
    setState(() => _connectedServerId = null);
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<VpnServer> get _sortedServers {
    final list = [..._servers];
    switch (_sortMode) {
      case _SortMode.favoriteFirst:
        list.sort((a, b) {
          if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
          return a.remark.compareTo(b.remark);
        });
        break;
      case _SortMode.byPing:
        list.sort((a, b) {
          final ap = a.lastPingMs ?? 999999;
          final bp = b.lastPingMs ?? 999999;
          return ap.compareTo(bp);
        });
        break;
      case _SortMode.byName:
        list.sort((a, b) => a.remark.compareTo(b.remark));
        break;
    }
    return list;
  }

  Future<void> _openSubscriptions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionsScreen(onServersUpdated: _replaceGroupServers),
      ),
    );
  }

  void _openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(servers: _servers)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AY-Tunnel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'آمار مصرف',
            onPressed: _openStats,
          ),
          IconButton(
            icon: const Icon(Icons.rss_feed),
            tooltip: 'سابسکریپشن‌ها',
            onPressed: _openSubscriptions,
          ),
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'مرتب‌سازی',
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: _SortMode.favoriteFirst, child: Text('موردعلاقه‌ها اول')),
              PopupMenuItem(value: _SortMode.byPing, child: Text('کمترین پینگ')),
              PopupMenuItem(value: _SortMode.byName, child: Text('نام سرور')),
            ],
          ),
        ],
      ),
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
                    itemCount: _sortedServers.length,
                    itemBuilder: (ctx, i) => _buildServerTile(_sortedServers[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'qr',
            onPressed: _scanQr,
            tooltip: 'اسکن QR',
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _showAddServerDialog,
            icon: const Icon(Icons.add),
            label: const Text('افزودن سرور'),
          ),
        ],
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                server.remark,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (server.groupTag != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  server.groupTag!,
                  style: TextStyle(fontSize: 10.5, color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          server.lastPingMs != null ? '${server.lastPingMs} ms' : 'تست‌نشده',
          style: const TextStyle(color: Colors.black45, fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                server.isFavorite ? Icons.star : Icons.star_border,
                color: server.isFavorite ? Colors.amber[700] : Colors.black38,
              ),
              tooltip: 'موردعلاقه',
              onPressed: () => _toggleFavorite(server),
            ),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}