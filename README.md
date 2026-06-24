# Spidy-Draw Graduation Project - Organized Full Package

دي نسخة منظمة لمشروع Spidy-Draw جاهزة للتسليم والعرض.


## حالة نسخة التسليم

تم تجهيز هذه النسخة للتسليم، وتم إصلاح خطأ `totalLines` الذي كان يمنع Flutter build داخل `dashboard_screen.dart`.
راجع `DELIVERY_READY_NOTES.md` قبل التشغيل النهائي.

## هيكلة المشروع

```text
Spidy-Draw-Final-Organized/
├─ app/                 تطبيق Flutter للموبايل
├─ device_code/         كود الجهاز ESP32 + أدوات Python اختيارية
│  ├─ firmware/         كود ESP32 PlatformIO
│  ├─ python_tools/     أدوات Python القديمة/الإضافية
│  └─ docs/             توثيق الجهاز
├─ sample_gcode/        ملفات G-code للتجربة
└─ scripts/             أوامر تشغيل مختصرة
```

## تشغيل تطبيق الموبايل

```bash
cd app
flutter clean
flutter pub get
flutter analyze
flutter run
```

لعمل APK:

```bash
cd app
flutter build apk --release
```

## رفع كود الجهاز على ESP32

```bash
cd device_code/firmware
pio run
pio run --target upload
```

## طريقة الاستخدام

1. ارفع كود الجهاز على ESP32.
2. شغل ESP32 واعرف عنوانه/IP.
3. افتح تطبيق الموبايل.
4. اكتب ESP URL فقط، مثال:

```text
http://192.168.4.1
```

5. اختار صورة أو التقط صورة بالكاميرا.
6. دخل Safe Area حسب مساحة الورقة/الجهاز.
7. اعمل Generate للـ G-code.
8. ارفع وشغل على ESP32.

## ملاحظات مهمة

- التطبيق لا يحتاج Python server في الوضع الحالي.
- التحويل من Image إلى G-code يتم داخل Flutter.
- `device_code/python_tools` موجود كأدوات اختيارية فقط.
- تم حذف ملفات build/cache القديمة مثل `.pio`, `.git`, `__pycache__` من النسخة المنظمة.
