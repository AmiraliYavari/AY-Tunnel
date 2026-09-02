/// یک تکه متن که ممکنه شامل چند لینک کانفیگ باشه رو (چه با خط جدید از هم
/// جدا شده باشن، چه بدون هیچ جداکننده‌ای به هم چسبیده باشن) به لینک‌های
/// مستقل می‌شکونه. ملاک شکستن، شروع هر پروتکل پشتیبانی‌شده‌ست
/// (vmess:// | vless:// | trojan:// | ss://).
List<String> splitConfigBlob(String input) {
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