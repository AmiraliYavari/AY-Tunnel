import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config_parser.dart';

/// مسئول گرفتن محتوای یک لینک سابسکریپشن و درآوردن لیست لینک‌های کانفیگ ازش.
/// خیلی از پنل‌ها محتوا رو به‌صورت Base64 برمی‌گردونن (استاندارد رایج
/// v2rayNG/v2rayN)؛ اگه Base64 نبود، همون متن خام رو مستقیم پارس می‌کنیم.
class SubscriptionService {
  Future<List<String>> fetchConfigs(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('سرور سابسکریپشن با کد ${response.statusCode} جواب داد.');
    }

    final body = response.body.trim();
    final decoded = _tryDecodeBase64(body) ?? body;
    return splitConfigBlob(decoded);
  }

  String? _tryDecodeBase64(String input) {
    try {
      // بعضی سابسکریپشن‌ها padding رو کم دارن؛ خودمون تکمیلش می‌کنیم.
      final normalized = input.replaceAll('\n', '').replaceAll('\r', '');
      final padded = normalized.padRight(
        normalized.length + (4 - normalized.length % 4) % 4,
        '=',
      );
      return utf8.decode(base64.decode(padded));
    } catch (_) {
      return null;
    }
  }
}