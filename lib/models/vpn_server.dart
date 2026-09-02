/// یک پروفایل سرور که کاربر از طریق لینک اشتراک (vmess://, vless://, trojan://, ss://)
/// اضافه کرده. فقط لینک خام رو نگه می‌داریم و هر بار موقع اتصال، دوباره پارسش می‌کنیم؛
/// این باعث میشه اگه فرمت پکیج flutter_v2ray عوض بشه، مجبور به مهاجرت داده نباشیم.
class VpnServer {
  final String id;
  final String remark; // اسم نمایشی سرور (از خود لینک استخراج میشه)
  final String rawLink; // لینک کامل vmess://, vless://, trojan://, ss://
  int? lastPingMs; // آخرین نتیجه‌ی تست پینگ (میلی‌ثانیه)، null یعنی هنوز تست نشده
  bool isFavorite; // علاقه‌مندی؛ سرورهای موردعلاقه بالای لیست میان
  String? groupTag; // اسم سابسکریپشنی که این سرور ازش اومده؛ null یعنی افزوده‌ی دستی
  int totalUploadBytes; // مجموع حجم آپلود مصرف‌شده روی این سرور (تقریبی)
  int totalDownloadBytes; // مجموع حجم دانلود مصرف‌شده روی این سرور (تقریبی)

  VpnServer({
    required this.id,
    required this.remark,
    required this.rawLink,
    this.lastPingMs,
    this.isFavorite = false,
    this.groupTag,
    this.totalUploadBytes = 0,
    this.totalDownloadBytes = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remark': remark,
        'rawLink': rawLink,
        'isFavorite': isFavorite,
        'groupTag': groupTag,
        'totalUploadBytes': totalUploadBytes,
        'totalDownloadBytes': totalDownloadBytes,
      };

  factory VpnServer.fromJson(Map<String, dynamic> json) => VpnServer(
        id: json['id'] as String,
        remark: json['remark'] as String,
        rawLink: json['rawLink'] as String,
        isFavorite: json['isFavorite'] as bool? ?? false,
        groupTag: json['groupTag'] as String?,
        totalUploadBytes: json['totalUploadBytes'] as int? ?? 0,
        totalDownloadBytes: json['totalDownloadBytes'] as int? ?? 0,
      );
}