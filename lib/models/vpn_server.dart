/// یک پروفایل سرور که کاربر از طریق لینک اشتراک (vmess://, vless://, trojan://, ss://)
/// اضافه کرده. فقط لینک خام رو نگه می‌داریم و هر بار موقع اتصال، دوباره پارسش می‌کنیم؛
/// این باعث میشه اگه فرمت پکیج flutter_v2ray عوض بشه، مجبور به مهاجرت داده نباشیم.
class VpnServer {
  final String id;
  final String remark; // اسم نمایشی سرور (از خود لینک استخراج میشه)
  final String rawLink; // لینک کامل vmess://, vless://, trojan://, ss://
  int? lastPingMs; // آخرین نتیجه‌ی تست پینگ (میلی‌ثانیه)، null یعنی هنوز تست نشده

  VpnServer({
    required this.id,
    required this.remark,
    required this.rawLink,
    this.lastPingMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remark': remark,
        'rawLink': rawLink,
      };

  factory VpnServer.fromJson(Map<String, dynamic> json) => VpnServer(
        id: json['id'] as String,
        remark: json['remark'] as String,
        rawLink: json['rawLink'] as String,
      );
}
