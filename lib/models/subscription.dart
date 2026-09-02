/// یک منبع سابسکریپشن (لینکی که هر بار فچ بشه، یه لیست از کانفیگ‌ها برمی‌گردونه).
/// خودِ کانفیگ‌ها به‌عنوان [VpnServer] با groupTag برابر با اسم این سابسکریپشن
/// ذخیره میشن؛ اینجا فقط منبع و زمان آخرین به‌روزرسانی رو نگه می‌داریم.
class Subscription {
  final String id;
  String remark; // اسم نمایشی سابسکریپشن
  final String url;
  DateTime? lastUpdated;

  Subscription({
    required this.id,
    required this.remark,
    required this.url,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remark': remark,
        'url': url,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        remark: json['remark'] as String,
        url: json['url'] as String,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String)
            : null,
      );
}