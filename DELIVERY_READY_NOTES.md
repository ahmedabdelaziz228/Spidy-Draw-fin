# Spidy-Draw Delivery Notes

هذه النسخة تم تجهيزها للتسليم السريع.

## أهم إصلاح تم تطبيقه

- تم إصلاح خطأ Flutter build في `app/lib/screens/dashboard_screen.dart`:
  - كان المتغير `totalLines` مستخدم داخل كارت الـ Dashboard بدون تعريف.
  - تم تعريفه من `_gcodeLines.length` داخل `_buildGraduationHero()`.

## إصلاح اختبار البداية

- تم تحديث `app/test/widget_test.dart` حتى:
  - يجهز `SharedPreferences` في بيئة الاختبار.
  - لا يعتمد على نص مطابق حرفيًا بينما عنوان الشاشة يحتوي على سطر جديد.
  - يتأكد من ظهور شاشة الاتصال وحقل `ESP32 URL`.

## أوامر التشغيل قبل التسليم

افتح Terminal داخل فولدر `app` وشغل:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

لعمل APK:

```bash
flutter build apk --release
```

مكان ملف APK بعد البناء:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

## لو ظهرت مشكلة Gradle wrapper أو ملفات Android ناقصة

داخل فولدر `app` شغل:

```bash
flutter create --platforms=android .
flutter pub get
```

ثم أعد تشغيل:

```bash
flutter run
```

## طريقة العرض أمام اللجنة

1. ارفع Firmware الموجود في `device_code/firmware` على ESP32.
2. شغل ESP32 واتصل من الموبايل على Wi-Fi الخاص به.
3. افتح التطبيق واكتب:

```text
http://192.168.4.1
```

4. اختار صورة أو صور بالكاميرا.
5. اضبط Safe Area حسب مساحة الورقة.
6. اضغط Generate G-code.
7. راجع Preview.
8. اضغط Upload ثم Run.

## ملاحظة مهمة

لم يتم بناء APK داخل هذه البيئة لأن Flutter SDK غير موجود هنا، لذلك الاختبار النهائي يجب أن يتم على جهازك باستخدام أوامر Flutter بالأعلى.
