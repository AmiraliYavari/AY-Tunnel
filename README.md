<div align="center">

# 🚀 AY-Tunnel

### کلاینت مدرن V2Ray / Xray ساخته‌شده با Flutter

یک اپ چندسکویی، سبک و زیبا برای مدیریت و اتصال به سرورهای V2Ray —
با پشتیبانی از لینک‌های اشتراک `vmess`، `vless`، `trojan` و `ss`.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-informational)](#-پلتفرم‌های-پشتیبانی‌شده)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#-مجوز)

</div>

---

## ✨ امکانات

| | |
|---|---|
| 🔗 | افزودن سرور با پیست کردن لینک اشتراک (`vmess://`, `vless://`, `trojan://`, `ss://`) |
| 💾 | ذخیره‌ی خودکار لیست سرورها روی خود دستگاه |
| ⚡ | تست پینگ (تأخیر) هر سرور با یک لمس |
| 🔌 | اتصال / قطع اتصال سریع و ساده |
| 📊 | نمایش زنده‌ی وضعیت اتصال، سرعت آپلود/دانلود و مدت زمان |
| 🌗 | ظاهر تیره و مینیمال بر پایه‌ی Material 3 |
| 🌍 | رابط کاربری راست‌به‌چپ و فارسی از پایه |

---

## 🖥️ پلتفرم‌های پشتیبانی‌شده

<div align="center">

| Android | iOS | Windows | macOS | Linux | Web |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ فقط مدیریت لیست سرورها* |

</div>

> \* پکیج هسته‌ی V2Ray (`flutter_v2ray`) یک پلاگین نیتیوعه و روی Web قابلیت اتصال واقعی VPN رو پشتیبانی نمی‌کنه.

---

## 🧱 ساختار پروژه

```
lib/
├── main.dart                     # نقطه‌ی شروع برنامه
├── models/
│   └── vpn_server.dart           # مدل داده‌ی یک پروفایل سرور
├── services/
│   └── storage_service.dart      # ذخیره و بازیابی لیست سرورها
├── screens/
│   └── home_screen.dart          # صفحه‌ی اصلی (لیست سرورها + اتصال)
└── widgets/                      # ویجت‌های قابل‌استفاده‌ی مجدد
```

---

## 🚀 شروع سریع

### پیش‌نیاز
- [Flutter SDK](https://docs.flutter.dev/get-started/install) نصب‌شده روی سیستم

### مراحل

```bash
# ۱. کلون کردن پروژه
git clone https://github.com/AmiraliYavari/AY-Tunnel.git
cd AY-Tunnel

# ۲. نصب وابستگی‌ها
flutter pub get

# ۳. اجرا (ترجیحاً روی گوشی/دستگاه واقعی؛ VPN رو نمیشه درست روی شبیه‌ساز تست کرد)
flutter run
```

---

## 📦 آماده‌سازی برای انتشار در Google Play

طبق مستندات پکیج [`flutter_v2ray`](https://pub.dev/packages/flutter_v2ray)، قبل از ساخت نسخه‌ی release دو تغییر لازمه:

**`android/gradle.properties`**
```properties
android.bundle.enableUncompressedNativeLibs=false
```

**`android/app/build.gradle`** — بلاک `buildTypes` رو با این جایگزین کن:
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

---

## 🗺️ نقشه‌ی راه

- [ ] اسکن QR Code برای وارد کردن سرور (پکیج `mobile_scanner`)
- [ ] پشتیبانی از subscription URL برای وارد کردن گروهی سرورها
- [ ] حالت «فقط پروکسی» (`proxyOnly: true`)
- [ ] اتصال خودکار به آخرین سرور بعد از باز کردن اپ
- [ ] گروه‌بندی و جستجوی سرورها

---

## ⚠️ نکته‌ی مهم درباره‌ی استفاده

این ابزار یک کلاینت پروکسی/VPN عمومیه. استفاده ازش رو با قوانین محل زندگیت و
شرایط استفاده‌ی سرویس‌دهنده‌ای که بهش وصل می‌شی هماهنگ کن.

---

## 📄 مجوز

این پروژه تحت مجوز MIT منتشر شده — آزادانه استفاده، تغییر و توزیع کن.

<div align="center">

ساخته‌شده با 💙 و Flutter

</div>