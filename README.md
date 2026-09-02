# کلاینت V2Ray با Flutter

یه نسخه‌ی اولیه و کاربردی از یه کلاینت V2Ray/Xray برای اندروید، شبیه به v2rayNG،
که با Flutter و پکیج [`flutter_v2ray`](https://pub.dev/packages/flutter_v2ray) ساخته شده.

## چیکار می‌کنه؟

- افزودن سرور با پیست کردن لینک اشتراک (`vmess://`, `vless://`, `trojan://`, `ss://`)
- ذخیره‌ی لیست سرورها روی خود دستگاه (با `shared_preferences`)
- تست پینگ (تأخیر) هر سرور
- اتصال/قطع اتصال VPN با یک لمس
- نمایش وضعیت اتصال، سرعت آپلود/دانلود و مدت زمان اتصال

## ساختار پروژه

```
lib/
  main.dart                  نقطه‌ی شروع برنامه
  models/vpn_server.dart     مدل داده‌ی یک پروفایل سرور
  services/storage_service.dart   ذخیره و بازیابی لیست سرورها
  screens/home_screen.dart   صفحه‌ی اصلی (لیست سرورها + اتصال)
pubspec.yaml                 وابستگی‌های پروژه
```

## راه‌اندازی (مرحله به مرحله)

این پروژه فقط شامل فایل‌های Dart/`pubspec.yaml` است. چون تولید کامل پوشه‌های
`android/` و `ios/` نیاز به اجرای Flutter SDK داره (که در محیط من در دسترس نیست)،
باید این دو دستور رو خودت روی سیستمت اجرا کنی:

1. **نصب Flutter SDK** (اگه نصب نداری): راهنمای رسمی در f

2. **ساخت پوشه‌های پلتفرم**، از داخل همین پوشه‌ی پروژه:
   ```bash
   flutter create .
   ```
   این دستور پوشه‌های `android/` و `ios/` رو بدون دست زدن به فایل‌های `lib/` که
   از قبل نوشتیم، اضافه می‌کنه.

3. **نصب وابستگی‌ها**:
   ```bash
   flutter pub get
   ```

4. **اجرا روی گوشی واقعی** (VPN رو نمیشه درست روی شبیه‌ساز تست کرد):
   ```bash
   flutter run
   ```

## تنظیمات لازم قبل از انتشار در Google Play

طبق مستندات پکیج `flutter_v2ray`، قبل از ساخت نسخه‌ی release باید دو تغییر بدی:

**`android/gradle.properties`** — این خط رو اضافه کن:
```
android.bundle.enableUncompressedNativeLibs=false
```

**`android/app/build.gradle`** — بلاک `buildTypes` رو با این جایگزین کن تا فقط
معماری‌های لازم پکیج بشن (حجم نهایی رو هم کم می‌کنه):
```gradle
splits {
    abi {
        enable true
        reset()
        include "x86_64", "armeabi-v7a", "arm64-v8a"
        universalApk true
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        ndk {
            abiFilters "x86_64", "armeabi-v7a", "arm64-v8a"
            debugSymbolLevel 'FULL'
        }
    }
}
```

## قدم بعدی‌های پیشنهادی

- اضافه کردن اسکن QR Code برای وارد کردن سرور (پکیج `mobile_scanner`)
- گروه‌بندی سرورها یا وارد کردن گروهی از یک لینک اشتراک (subscription URL)
- افزودن حالت "فقط پروکسی" (`proxyOnly: true`) برای وقتی نمی‌خوای کل ترافیک گوشی رو عبور بدی
- ذخیره‌ی خودکار آخرین سرور متصل و اتصال مجدد بعد از باز کردن اپ

## نکته‌ی مهم درباره‌ی استفاده

این ابزار یک کلاینت پروکسی/VPN عمومیه؛ استفاده ازش رو با قوانین محل زندگیت و
شرایط استفاده‌ی سرویس‌دهنده‌ای که بهش وصل میشی هماهنگ کن.
