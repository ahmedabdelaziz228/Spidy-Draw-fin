# Spidy Draw Graduation App

تطبيق Flutter للتحكم المباشر في روبوت الرسم Spidy Draw عن طريق ESP32 فقط.


## حالة نسخة التسليم

تم إصلاح خطأ Dashboard الخاص بـ `totalLines` وتم تحديث اختبار البداية.
قبل التسليم شغل: `flutter clean`, `flutter pub get`, `flutter analyze`, ثم `flutter run`.

## الفكرة

التطبيق لا يحتاج Python server في التشغيل اليومي.

```text
Image / Camera
→ Local Flutter Image Processing
→ Generate G-code
→ Upload G-code to ESP32
→ Run Robot
```

## المميزات

- إدخال ESP32 URL واحد فقط.
- اختيار صورة من المعرض.
- التقاط صورة بالكاميرا.
- تحويل الصورة إلى G-code داخل Flutter.
- Safe Drawing Area يدخلها المستخدم:
  - Start X
  - Start Y
  - Safe Width
  - Safe Height
- Preview لمسار الرسم قبل الرفع.
- Upload / Run / Stop / Clear / Home.
- Manual movement pad.
- Pen Up / Pen Down.
- Live status من ESP32.
- UI احترافي مناسب لعرض مشروع تخرج.

## ESP32 endpoints المطلوبة

التطبيق يتوقع أن Firmware الـ ESP32 يدعم endpoints الآتية:

```text
GET  /status
POST /upload-text
GET  /execute
GET  /stop
GET  /clear
GET  /home
GET  /servo?pos=0
GET  /servo?pos=1
GET  /move?angle=90&repeats=1
```

## التشغيل

افتح المشروع في VS Code أو Android Studio، ثم نفذ:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## بناء APK

```bash
flutter build apk --release
```

الـ APK سيظهر غالبًا في:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## ملاحظات مهمة

- التطبيق يستخدم HTTP عادي للاتصال بالـ ESP32، لذلك `usesCleartextTraffic=true` مفعلة في AndroidManifest.
- Android permissions مضافة للإنترنت والكاميرا والصور.
- لو Android Gradle wrapper اتطلب عندك، نفذ داخل فولدر المشروع:

```bash
flutter create --platforms=android .
flutter pub get
```

ثم شغل التطبيق عادي. هذا الأمر لا يغيّر كود `lib` الأساسي للتطبيق، لكنه يعيد توليد ملفات Android platform لو ناقصة عند جهازك.

## Default ESP URL

```text
http://192.168.4.1
```

تقدر تغيّره من شاشة الاتصال داخل التطبيق.

## Android v2 embedding note
This project includes the modern Flutter Android v2 embedding:

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/spidy_draw/MainActivity.kt`
- `flutterEmbedding = 2`

If Android files are regenerated, run:

```bash
flutter create --platforms=android .
flutter pub get
```
