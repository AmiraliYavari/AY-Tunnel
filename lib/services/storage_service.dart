import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../models/vpn_server.dart';

/// مسئول خواندن/نوشتن لیست سرورها و سابسکریپشن‌ها روی حافظه‌ی محلی دستگاه.
/// جدا نگه داشتنش از UI باعث میشه بعداً بشه راحت جایگزینش کرد
/// (مثلاً با یه دیتابیس واقعی مثل sqlite) بدون دست زدن به بقیه‌ی کد.
class StorageService {
  static const _serversKey = 'saved_servers';
  static const _subscriptionsKey = 'saved_subscriptions';

  Future<List<VpnServer>> loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_serversKey) ?? [];
    return raw
        .map((s) => VpnServer.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveServers(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = servers.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_serversKey, raw);
  }

  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_subscriptionsKey) ?? [];
    return raw
        .map((s) => Subscription.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSubscriptions(List<Subscription> subs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = subs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_subscriptionsKey, raw);
  }
}