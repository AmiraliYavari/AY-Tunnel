import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_server.dart';

/// مسئول خواندن/نوشتن لیست سرورها روی حافظه‌ی محلی دستگاه.
/// جدا نگه داشتنش از UI باعث میشه بعداً بشه راحت جایگزینش کرد
/// (مثلاً با یه دیتابیس واقعی مثل sqlite) بدون دست زدن به بقیه‌ی کد.
class StorageService {
  static const _serversKey = 'saved_servers';

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
}
