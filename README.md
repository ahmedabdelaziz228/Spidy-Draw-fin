# 🕷️ Spidy-Draw — Graduation Project

**Spidy-Draw** is a portable ESP32-based cable-driven drawing robot controlled from a Flutter mobile application.  
The system converts an image or camera photo into drawing paths, generates ESP-compatible G-code locally on the phone, uploads it directly to the ESP32, and executes the drawing using synchronized stepper motors and a pen servo.

> **Final submission note:** All previous Markdown documentation has been consolidated into this single root `README.md`. The rest of the project is kept clean for graduation delivery.

---

## 1. Project Summary

Spidy-Draw is an end-to-end robotic drawing system:

```text
Image / Camera
→ Local Flutter image processing
→ Contour/path extraction
→ Safe Area mapping
→ ESP-compatible G-code
→ Upload to ESP32
→ Robot drawing execution
```

The project is **not a traditional rigid XY plotter**. It is designed as a **cable-driven robot**, where the ESP32 firmware controls four stepper motors through cable/pulley motion and uses a servo motor for pen up/down control.

### Arabic summary

مشروع **Spidy-Draw** عبارة عن روبوت رسم محمول يعتمد على ESP32 وتطبيق Flutter.  
المستخدم يختار صورة أو يلتقط صورة بالكاميرا، والتطبيق يحولها إلى G-code داخل الموبايل، ثم يرفعها مباشرة إلى ESP32 بدون الحاجة إلى Python server أثناء التشغيل اليومي، وبعدها الروبوت ينفذ الرسم على الورقة.

---

## 2. Main Features

### Mobile App Features

- Professional graduation-ready Flutter UI.
- One ESP32 URL only; no Python server is required for daily operation.
- Pick an image from gallery.
- Capture an image using the camera.
- Convert image to G-code locally inside Flutter.
- Preview the generated drawing path before uploading.
- User-editable Safe Drawing Area:
  - Start X
  - Start Y
  - Safe Width
  - Safe Height
- A4 workspace support: `210 × 297 mm`.
- Upload generated G-code directly to ESP32.
- Run, stop, clear, home, pen up, and pen down controls.
- Manual movement pad for calibration.
- Live ESP32 status polling.
- Performance fixes for smoother manual movement.
- Stable UI behavior on Android devices.

### ESP32 Firmware Features

- ESP32 web communication layer.
- G-code parser.
- Command queue execution.
- Four stepper motor coordination.
- Cable-driven motion model.
- Pen servo control.
- Movement segmentation for smoother lines.
- Direct execution of uploaded coordinates.
- Device-side endpoints for mobile control.

### Optional Python Tools

The current mobile workflow does **not** require a Python server.  
The `device_code/python_tools/` folder remains available for experiments, comparison, image-processing testing, and legacy development workflows.

---

## 3. Project Structure

```text
Spidy-Draw-fin-main/
├─ app/                         Flutter mobile application
│  ├─ lib/                      Main Dart source code
│  ├─ assets/                   App assets/logo
│  ├─ android/                  Android platform files
│  ├─ web/                      Flutter web support
│  ├─ sample_gcode/             Sample G-code files
│  └─ scripts/                  App helper scripts
│
├─ device_code/                 ESP32 firmware and optional tools
│  ├─ firmware/                 PlatformIO ESP32 firmware
│  │  ├─ include/               Header/config files
│  │  ├─ src/                   Main C++ firmware source
│  │  ├─ web/                   ESP web files if available
│  │  └─ platformio.ini         PlatformIO board configuration
│  │
│  └─ python_tools/             Optional legacy/experimental Python tools
│
├─ sample_gcode/                Root-level G-code samples
├─ scripts/                     Helper scripts for app/firmware
├─ README.md                    Main consolidated documentation file
└─ .gitignore
```

---

## 4. Requirements

### Flutter App

- Flutter SDK compatible with Dart `>=3.4.0 <4.0.0`.
- Android device or emulator.
- Network access to the ESP32 hotspot or local network.
- Required Flutter dependencies are listed in `app/pubspec.yaml`.

Current app package info:

```yaml
name: spidy_draw
description: ESP32-only controller app for the Spidy-Draw cable robot with local image-to-G-code conversion.
version: 1.3.0+4
```

### ESP32 Firmware

- PlatformIO.
- ESP32 board compatible with the configured environment in `device_code/firmware/platformio.ini`.
- Required library:
  - `madhephaestus/ESP32Servo`

---

## 5. How to Run the Mobile App

From the project root:

```bash
cd app
flutter clean
flutter pub get
flutter analyze
flutter run
```

To build a release APK:

```bash
cd app
flutter build apk --release
```

Expected APK output path:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. How to Upload Firmware to ESP32

From the project root:

```bash
cd device_code/firmware
pio run
pio run --target upload
```

To open serial monitor:

```bash
pio device monitor
```

Default firmware Wi-Fi settings are defined in:

```text
device_code/firmware/include/config.h
```

Default hotspot values from the current firmware:

```cpp
AP_SSID = "CableRobot_Hotspot"
AP_PASSWORD = "robot123"
```

---

## 7. ESP32 Endpoints Used by the App

The Flutter app expects one ESP32 base URL and talks directly to these endpoints:

```text
GET  /status
POST /upload-text
GET  /execute
GET  /stop
GET  /clear
GET  /home
GET  /servo?pos=0|1
GET  /move?angle=...&repeats=...
```

Typical ESP URL examples:

```text
http://192.168.4.1
http://192.168.1.50
```

---

## 8. Safe Area and Workspace

The default logical paper workspace is A4:

```text
Paper Width:  210 mm
Paper Height: 297 mm
```

Default Safe Area:

```text
X = 20 mm
Y = 20 mm
W = 170 mm
H = 257 mm
```

The app lets the user edit the Safe Area. Generated G-code points are clamped inside the selected area to avoid drawing outside the paper.

---

## 9. Image-to-G-code Pipeline

The current app-side converter follows a contour/vector-like workflow designed to be closer to the original Python/OpenCV behavior:

```text
Image
→ Resize to A4 workspace aspect ratio
→ Grayscale
→ Threshold
→ Black-stroke foreground extraction
→ Morphological cleanup
→ Contour extraction
→ Duplicate point removal
→ Path simplification
→ Path ordering
→ Safe Area mapping
→ ESP-compatible G-code
```

The generated G-code uses simple ESP-compatible commands:

```gcode
M5
G0 X.. Y..
M3
G1 X.. Y..
M5
```

Where:

- `M5` = pen up
- `M3` = pen down
- `G0` = move without drawing
- `G1` = draw/move while pen is down

---

## 10. Hardware Model

Spidy-Draw is built around:

- ESP32 microcontroller.
- Four stepper motors.
- One servo motor.
- Cable/pulley motion system.
- Pen holder mechanism.
- Fixed paper/drawing surface.
- Power supply and motor drivers.

Important mechanical interpretation:

- Treat the robot as **cable-driven**.
- Do not silently convert the logic into a classic XY gantry.
- Motion depends on cable geometry and motor direction validation.
- Hardware calibration must be done with real tests.

---

## 11. Recommended Demo Flow

Use this sequence for the graduation presentation:

1. Power on the ESP32 robot.
2. Connect the phone to the ESP32 hotspot or the same Wi-Fi network.
3. Open the Flutter app.
4. Enter the ESP32 URL.
5. Check live status.
6. Choose an image or take a photo.
7. Adjust threshold/conversion settings if needed.
8. Set the Safe Drawing Area.
9. Preview the generated G-code path.
10. Upload G-code to ESP32.
11. Press Run.
12. Demonstrate Stop, Clear, Home, Manual Move, Pen Up, and Pen Down.

---

## 12. Hardware Test Order

Before presenting a complex image, validate movement using this order:

```text
1. Straight line
2. Square
3. Circle
4. Simple logo/icon
5. Signature or outline drawing
6. Final graduation demo image
```

If the line is wrong, inspect:

- motor direction
- steps/mm calibration
- cable geometry
- workspace dimensions
- firmware transform logic
- G-code coordinate mapping

---

## 13. Stability and Performance Notes

The final package includes fixes for:

- Dashboard compile issue related to `totalLines`.
- Manual movement responsiveness.
- Long-press repeated movement.
- Reduced UI rebuilds during movement.
- G-code preview rendering performance.
- Status polling backoff when ESP is offline.
- Hit-test/render-size crash prevention.
- Safe Area field clamping and visual preview.
- Upload status feedback after successful upload.

---

## 14. Known Issues and Future Improvements

Known engineering points that should be validated on real hardware:

- Motor direction signs may need real testing.
- Steps/mm require calibration.
- Workspace dimensions must match the real physical drawing area.
- Very complex photos should be simplified before drawing.
- Local image conversion is optimized for logos, icons, signatures, and high-contrast drawings.
- Optional future improvement: add a cloud/local upload storage or richer preview export.

---

## 15. Troubleshooting

### Flutter build fails

Run:

```bash
cd app
flutter clean
flutter pub get
flutter analyze
flutter run
```

### Android cannot access ESP32 URL

Check:

- Phone is connected to ESP hotspot or same network.
- ESP IP address is correct.
- URL starts with `http://`.
- Android cleartext traffic is enabled in the manifest.

Current Android manifest includes:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CAMERA" />
```

### ESP upload fails

Run:

```bash
cd device_code/firmware
pio run
pio run --target upload
```

Check:

- USB cable supports data.
- Correct board/port is selected.
- Serial monitor is closed during upload.
- ESP32 drivers are installed.

### Drawing is mirrored or distorted

Check:

- motor direction signs
- anchor model
- steps/mm
- paper dimensions
- Safe Area settings
- firmware coordinate assumptions

---

## 16. Submission Checklist

Before delivery:

- [ ] Run `flutter analyze`.
- [ ] Run app on a real Android phone.
- [ ] Test ESP connection.
- [ ] Upload a small G-code sample.
- [ ] Test line, square, and circle.
- [ ] Build release APK.
- [ ] Upload firmware successfully.
- [ ] Prepare a simple image demo.
- [ ] Keep this single `README.md` as the main documentation.
- [ ] Do not include scattered Markdown patch notes.

---

## 17. Consolidated Documentation Sources

The following Markdown files were merged into this single root `README.md` and removed from their old locations:

- `app/README.md`
- `app/README_ESP_ONLY_PATCH.md`
- `app/README_GRADUATION_UI_PATCH.md`
- `app/README_IMAGE_TO_ESP_PATCH.md`
- `DELIVERY_READY_NOTES.md`
- `device_code/docs/AGENTS.md`
- `device_code/docs/ARCHITECTURE.md`
- `device_code/docs/HARDWARE_MODEL.md`
- `device_code/docs/KNOWN_ISSUES.md`
- `device_code/docs/PROJECT_CONTEXT.md`
- `device_code/docs/TASKS.md`
- `device_code/firmware/README.md`
- `device_code/python_tools/README.md`
- `device_code/README.md`
- `FIRMWARE_APP_FINAL_FIX_NOTES.md`
- `OLD_GCODE_ORDER_MATCH_FIX.md`
- `OLD_WORKING_PIPELINE_COMPARISON.md`
- `PERFORMANCE_FIX_NOTES.md`
- `PYTHON_EQUIVALENT_GCODE_NOTES.md`
- `STABILITY_FIX_NOTES.md`
- `UI_SAFEAREA_PERFORMANCE_FIX_NOTES.md`

---

# Appendix — Original Markdown Documentation Archive

The sections below preserve the important content from the previous Markdown files in one place. They are collapsed to keep the main README clean.

<details>
<summary><strong>app/README.md</strong></summary>

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

</details>

<details>
<summary><strong>app/README_ESP_ONLY_PATCH.md</strong></summary>

# Spidy Draw - ESP URL Only Flutter App Patch

This package replaces the Flutter mobile app UI so it talks directly to the ESP32 only.

## What changed

- Removed Python server URL from the app UI.
- Connection screen now has one field only: ESP32 URL.
- Added direct ESP API service for:
  - `GET /status`
  - `POST /upload-text`
  - `GET /execute`
  - `GET /stop`
  - `GET /clear`
  - `GET /home`
  - `GET /servo?pos=0|1`
  - `GET /move?angle=...&repeats=...`
- Added status polling every 2 seconds.
- Added safer confirmation before running motors.
- Added cleaner dashboard UI.
- Fixed Android manifest issue:
  - Added INTERNET permission.
  - Kept cleartext HTTP enabled for local ESP URL.
  - Fixed the invalid `android:usesCleartextTraffic="true">>` typo.

## How to install

Copy the files in this ZIP over the same paths in your existing project.

Then run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

For release APK:

```bash
flutter build apk --release
```

## Important

This app now controls ESP32 directly. Image-to-G-code conversion is not inside the mobile app. Generate G-code elsewhere, then upload the `.gcode`, `.nc`, or `.txt` file from the app.

</details>

<details>
<summary><strong>app/README_GRADUATION_UI_PATCH.md</strong></summary>

# Spidy Draw — Graduation UI Patch

This patch upgrades the Flutter mobile app UI for a graduation project presentation while keeping the same ESP32-only architecture.

## What changed

- Redesigned connection screen with a professional hero panel.
- One ESP32 URL only. No Python server URL is required.
- New graduation dashboard header: `Image → Safe Area → G-code → ESP32`.
- Live robot status card with progress, pen, X/Y, and connection state.
- Demo workflow card showing the full project pipeline step by step.
- Polished Image-to-G-code studio with preview and conversion settings.
- Safe Drawing Area is still user-editable: Start X, Start Y, Safe Width, Safe Height.
- New professional G-code path preview with grid, glow lines, and Safe Area label.
- Cleaner cards, buttons, status pills, gradients, and app background.
- Manual calibration pad redesigned for demo/presentation.

## Replace these files/folders

Copy the included files over your project with the same paths.

Important updated files:

```text
pubspec.yaml
lib/theme/app_theme.dart
lib/screens/connection_screen.dart
lib/screens/dashboard_screen.dart
lib/widgets/app_background.dart
lib/widgets/section_card.dart
lib/widgets/info_tile.dart
lib/widgets/workflow_step.dart
lib/widgets/primary_button.dart
lib/widgets/status_pill.dart
lib/widgets/gcode_path_preview.dart
```

## Run

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Build APK

```bash
flutter build apk --release
```

## Notes

This is a UI/UX patch. It does not remove image-to-G-code, safe area, or ESP upload/run features from the previous patch.

</details>

<details>
<summary><strong>app/README_IMAGE_TO_ESP_PATCH.md</strong></summary>

# Spidy Draw - Image to G-code to ESP Flutter App Patch

This package upgrades the ESP-only Flutter app so the phone can:

1. Connect to one ESP32 URL only.
2. Pick an image from gallery or take a photo.
3. Convert the image locally inside Flutter to simple raster G-code.
4. Preview the generated drawing path.
5. Upload the G-code directly to the ESP32.
6. Run / stop / clear / home / move / pen up/down from the app.

## Important behavior

The conversion is local and does **not** use Python/OpenCV. It is intentionally simple and safe for mobile:

- Converts image to black/white using a Threshold slider.
- Generates horizontal drawing strokes from black pixel runs.
- Limits generated commands to 5500 by default to stay below the ESP queue limit.
- Uses `M5`, `G0`, `M3`, `G1`, `M5` for each drawn segment.

This is best for logos, icons, signatures, and simple high-contrast images. Complex photos should be simplified first or tuned with the app sliders.

## Files changed/added

Replace these files in your existing project:

- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- `lib/core/app_constants.dart`
- `lib/screens/dashboard_screen.dart`

Add these new files:

- `lib/models/generated_gcode.dart`
- `lib/services/image_to_gcode_converter.dart`
- `lib/widgets/gcode_path_preview.dart`

Existing ESP service files remain compatible with:

- `GET /status`
- `POST /upload-text`
- `GET /execute`
- `GET /stop`
- `GET /clear`
- `GET /home`
- `GET /servo?pos=0|1`
- `GET /move?angle=...&repeats=...`

## How to install

Copy the files in this ZIP over the same paths in your existing Flutter project.

Then run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

For APK:

```bash
flutter build apk --release
```

## Recommended first test

1. Connect phone to ESP Wi-Fi.
2. Open app and connect to `http://192.168.4.1`.
3. Choose a simple black logo image.
4. Press `تحويل فقط`.
5. Check preview.
6. Press `رفع فقط` first.
7. Then press `تشغيل الموجود` after confirming the robot is safe.

If the preview is too full/black, reduce Threshold or turn off Invert. If it is too empty, increase Threshold or turn on Invert.

</details>

<details>
<summary><strong>DELIVERY_READY_NOTES.md</strong></summary>

# Spidy-Draw Delivery Notes

## أوامر التشغيل

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

</details>

<details>
<summary><strong>device_code/docs/AGENTS.md</strong></summary>

# AGENTS.md

## Project Identity
This repository is for **Spidy-Draw**, a portable **ESP32 cable-driven drawing robot**.

The system converts:
**image → paths → G-code → ESP32 execution**

This is not a traditional rigid XY plotter project.

## Required Reading Order
Before making any change, read these files in this order:

1. `PROJECT_CONTEXT.md`
2. `TASKS.md`
3. `README.md`
4. `docs/ARCHITECTURE.md`
5. `docs/HARDWARE_MODEL.md`
6. `docs/KNOWN_ISSUES.md`
7. `TECHNICAL_DOCUMENTATION.md` if present

If there is any conflict:
- `PROJECT_CONTEXT.md` is the main engineering source of truth
- `TASKS.md` defines current priorities
- the actual source code wins over outdated docs
- public README may be simplified and should not override engineering reality

## Core Reality of This Project
Important facts that must not be forgotten:

- This project is **cable-driven**
- It is **not** a classic XY gantry / frame plotter
- The **image-processing side** runs on Python / laptop / browser side
- The **motion-execution side** runs on ESP32 firmware side
- The robot uses:
  - 4 stepper motors
  - 1 servo for pen up/down
  - cable-length based motion logic
  - G-code execution through firmware queue
- Any refactor that silently turns the project into a traditional XY plotter is wrong

## Safe Change Policy
When editing this repository:

- prefer minimal, explicit patches
- explain the reason for each motion-related change
- do not blindly change motor direction signs without a real hardware test
- do not invent geometry values that are not justified by code or docs
- do not silently change workspace units or paper model
- do not duplicate transforms between Python-side generation and firmware-side execution
- do not move heavy image processing onto ESP32 unless explicitly requested

## Current High-Risk Areas
These are the most important technical risks already identified:

1. **Possible double transform / double fit**
2. **Segmentation / interpolation bug**
3. **Workspace mismatch**
4. **Motor direction uncertainty**
5. **Legacy / stale documentation**

## Files That Matter Most

### Python / Processing Side
- `image_processor.py`
- `path_optimizer.py`
- `web_handlers.py`
- `gcode_exporter.py`
- `bridge_server.py`
- `preset_modes.py`

### Firmware / ESP32 Side
- `include/config.h`
- `include/gcode_executor.h`
- `include/gcode_parser.h`
- `include/gcode_validator.h`
- `include/kinematics.h`
- `include/motor_control.h`
- `include/servo_control.h`
- `include/robot_state.h`
- `src/gcode_executor.cpp`
- `src/gcode_parser.cpp`
- `src/kinematics.cpp`
- `src/motor_control.cpp`
- `src/servo_control.cpp`
- `src/web_server.cpp`
- `src/main.cpp`

## Validation Expectations
After making changes:
- run Python-side syntax and logic checks if possible
- run tests if available
- report exactly what was verified and what was not
- distinguish between static reasoning, local tests, and real hardware verification

Never claim a hardware fix is confirmed unless it was tested on the actual device.

</details>

<details>
<summary><strong>device_code/docs/ARCHITECTURE.md</strong></summary>

# ARCHITECTURE.md

## Overview
Spidy-Draw is organized as a layered system with a strong separation between processing and execution.

The practical pipeline is:
**Image → Paths → G-code → Queue → Motion Execution**

## Layer 1 — Image Processing Layer
Runs on Python side.

Responsibilities:
- load image files
- preprocess image
- detect contours
- simplify contours into paths
- remove duplicate / near-duplicate points
- calculate path metadata
- serialize results for preview and G-code generation

## Layer 2 — G-code Generation Layer
Runs on Python side.

Responsibilities:
- validate processed paths
- transform paths into workspace coordinates
- apply safe margins
- generate G-code commands
- provide preview / stats / debug exports

## Layer 3 — Firmware Parsing / Execution Layer
Runs on ESP32.

Responsibilities:
- parse G-code
- prepare queue
- apply transform / fit logic if used
- manage execution state machine
- trigger pen actions
- prepare movement segments
- call kinematics and motor control

## Layer 4 — Motion / Hardware Control Layer
Low-level execution layer.

Responsibilities:
- compute kinematics
- convert motion targets into motor steps
- synchronize motor stepping
- drive pen servo
- maintain robot state

## Design Principle
Keep heavy processing off the ESP32:
- image processing stays on Python / laptop / browser side
- ESP32 focuses on parsing and motion execution

</details>

<details>
<summary><strong>device_code/docs/HARDWARE_MODEL.md</strong></summary>

# HARDWARE_MODEL.md

## Hardware Summary
Spidy-Draw is built around an ESP32-controlled cable-driven motion system.

The hardware model includes:
- 4 stepper motors
- 1 servo motor
- cable / pulley based motion
- pen holder / pen up-down mechanism
- ESP32 microcontroller
- power system
- fixed drawing surface / paper

## Hardware Roles
### ESP32
- firmware execution
- queue handling
- device-side web communication
- coordinating motion execution
- controlling servo state

### Stepper Motors
- executing synchronized cable-driven movement
- contributing to target position changes through motion logic

### Servo
- pen up
- pen down

## Mechanical Interpretation Rules
- this project must be treated as **cable-driven**
- it must not be silently treated as a rigid XY gantry
- motion comes from cable / geometry relationships
- the code must preserve that logic

## Practical Validation Procedure
Run:
1. line
2. square
3. circle

If the line is wrong:
- inspect transform logic
- inspect motor directions
- inspect steps/mm
- inspect segmentation

</details>

<details>
<summary><strong>device_code/docs/KNOWN_ISSUES.md</strong></summary>

# KNOWN_ISSUES.md

## Confirmed / Suspected Issues

### 1. Double Transform / Double Fit
Status: fixed in current project package

Description:
- App/Python-side generation fits paths into final workspace coordinates.
- Firmware transform is disabled and executes uploaded coordinates directly.

### 2. Segmentation / Interpolation Bug
Status: fixed in current project package

Description:
- Firmware stores the start point of each long move and computes intermediate points with explicit linear interpolation.

### 3. Workspace Mismatch
Status: suspected high-priority issue

Description:
- Python and firmware may not share the same workspace dimensions or paper model

### 4. Motor Direction Ambiguity
Status: unresolved until hardware test

Description:
- sign conventions may be unclear from theory alone

### 5. Legacy Documentation / Stale Files
Status: ongoing risk

Description:
- some files may represent earlier design stages

</details>

<details>
<summary><strong>device_code/docs/PROJECT_CONTEXT.md</strong></summary>

# PROJECT_CONTEXT.md

## Project Summary
Spidy-Draw is a portable cable-driven drawing robot based on **ESP32**.

The full workflow is:
1. image is uploaded
2. image is converted into vector-like paths
3. paths are cleaned, simplified, and optionally reordered
4. validated G-code is generated
5. G-code is uploaded to the ESP32
6. ESP32 executes the drawing using synchronized motion control

This project is best understood as an end-to-end:
**image → paths → validated G-code → drawing execution**
pipeline.

## High-Level Architecture

### Python / Laptop / Browser Side
Responsible for:
- image loading
- preprocessing
- contour extraction
- path simplification
- point cleanup
- path ordering
- G-code generation
- upload bridge / local UI support

Main files:
- `image_processor.py`
- `path_optimizer.py`
- `web_handlers.py`
- `gcode_exporter.py`
- `bridge_server.py`
- `preset_modes.py`

### ESP32 / Firmware Side
Responsible for:
- G-code parsing
- queue preparation
- transform application
- kinematics
- synchronized motor stepping
- servo pen control
- robot state tracking
- device-side web endpoints

Main files:
- `src/gcode_executor.cpp`
- `src/gcode_parser.cpp`
- `src/kinematics.cpp`
- `src/motor_control.cpp`
- `src/servo_control.cpp`
- `src/web_server.cpp`
- `src/main.cpp`

## Mechanical Understanding
- the project is **cable-driven**
- it is **not** a classic XY gantry plotter
- ESP32 executes motion, not heavy image processing
- Python is responsible for image-to-G-code pipeline

## Known Critical Risks
1. possible double transform / double fit
2. possible segmentation interpolation issue
3. possible workspace mismatch
4. motor direction signs must be verified experimentally
5. some files may reflect older project stages

## Stable Conclusions
- the project is split between processing side and execution side
- the project is cable-driven
- ESP32 executes motion
- Python generates and prepares G-code
- transform logic, segmentation, workspace consistency, and hardware calibration are the main technical concerns

## Rules for Future Contributors / Agents
- do not assume XY plotter geometry
- do not assume every doc is current
- do not change workspace defaults without checking both Python and firmware
- keep public README simpler than engineering context, but never let README contradict the real project

</details>

<details>
<summary><strong>device_code/docs/TASKS.md</strong></summary>

# TASKS.md

## Current Priorities
### Priority 1 — Hardware calibration path
- verify motor directions by real test
- verify steps/mm with measured motion
- validate line, square, and circle quality

### Completed — Transform logic
- app generation fits G-code into the selected Safe Area
- firmware executes uploaded coordinates directly with transform disabled

### Completed — Segmentation
- firmware uses explicit linear interpolation between stored segment start and target
- long moves remain linear and evenly spaced

### Priority 2 — Unify workspace assumptions
- compare Python defaults vs firmware config
- remove accidental mismatch
- document the chosen workspace clearly

## Do Not Do Yet
- do not globally flip all motor direction signs without real hardware validation
- do not rewrite the whole architecture
- do not convert the project to a traditional XY plotter abstraction

## Recommended Test Order
1. straight line
2. square
3. circle
4. simple outline / signature
5. image-to-drawing comparison

</details>

<details>
<summary><strong>device_code/firmware/README.md</strong></summary>

# Spidy-Draw ESP32 Firmware

ده فولدر كود الجهاز نفسه للـ ESP32.

## المحتويات

- `platformio.ini` إعدادات PlatformIO والبورد.
- `src/` ملفات C++ الرئيسية.
- `include/` ملفات الهيدر والإعدادات.
- `web/` ملفات واجهة الويب الخاصة بالـ ESP لو موجودة.

## التشغيل والرفع على ESP32

افتح Terminal داخل الفولدر ده:

```bash
cd device_code/firmware
pio run
pio run --target upload
```

بعد الرفع، شغل الجهاز واتصل بشبكة الـ ESP32 أو بنفس الشبكة حسب إعداداتك، ثم افتح عنوان الـ ESP من التطبيق.

## Endpoints المستخدمة من تطبيق الموبايل

التطبيق يستخدم ESP URL واحد فقط ويتعامل مع:

- `/status`
- `/upload-text`
- `/execute`
- `/stop`
- `/clear`
- `/home`
- `/servo?pos=0|1`
- `/move?angle=...&repeats=...`

</details>

<details>
<summary><strong>device_code/python_tools/README.md</strong></summary>

# Spidy-Draw

Spidy-Draw is an ESP32-based cable-driven drawing robot. It converts an uploaded image into drawable paths, generates ESP-compatible G-code on a Python host, and executes that G-code on an ESP32 using four synchronized stepper motors and a pen servo.

This is not a classic rigid XY plotter. The firmware drives a cable/pulley mechanism and computes motor motion from cable-length changes.

## Overview

The project is split into two active runtime sides:

- **Python side:** image processing, path extraction, path cleanup, path ordering, preview data, and G-code generation.
- **ESP32 side:** G-code parsing, command queueing, pen control, motion segmentation, cable kinematics, and motor stepping.

The current default workspace model is A4 paper: `210 x 297 mm`. Python-side G-code generation fits drawings into that workspace. The firmware executes uploaded G-code coordinates directly and uses cable kinematics to convert target points into four motor step plans.

## Features

- Image upload and browser-based processing UI.
- OpenCV-based grayscale, threshold, contour extraction, and cleanup pipeline.
- Presets for logos, signatures, fine art, and outlines.
- Path simplification and near-duplicate point filtering.
- Optional path ordering to reduce pen-up travel.
- ESP-compatible G-code output using `G0`, `G1`, `M3`, and `M5`.
- Local bridge endpoint for uploading generated G-code to the ESP32.
- ESP32 Wi-Fi access point and device web interface.
- G-code upload from file or plain text.
- Servo-based pen up/down control.
- Long-move segmentation on firmware side.
- Four-motor cable-length kinematics with synchronized stepping.

## Architecture Summary

```text
Image
  -> Python image processing
  -> vector-like paths in workspace millimeters
  -> Python G-code generation and fit-to-paper
  -> upload to ESP32
  -> firmware G-code queue
  -> segmented target points
  -> cable-length kinematics
  -> synchronized stepper motion + servo pen control
```

### Python Processing Side

Active files:

- `bridge_server.py` - local HTTP server for the browser UI and API endpoints.
- `web/index.html` - Python-side browser UI for image processing and G-code generation.
- `web_handlers.py` - request handlers for image processing, validation, preview, G-code generation, and ESP upload.
- `image_processor.py` - OpenCV image loading, preprocessing, contour extraction, simplification, and pixel-to-mm mapping.
- `path_optimizer.py` - path cleanup and greedy path ordering.
- `preset_modes.py` - stable processing presets.
- `gcode_exporter.py` - helper exports for G-code, SVG, JSON, and stats.

Responsibilities:

- Load and preprocess images.
- Extract contours and convert them into workspace-coordinate paths.
- Simplify paths and remove redundant points.
- Fit generated G-code into the configured paper workspace.
- Generate commands supported by the ESP32 firmware.
- Upload generated G-code to the ESP32 when requested.

### ESP32 Firmware Side

Active files:

- `src/main.cpp` - firmware entry point; initializes state, motors, servo, Wi-Fi, web server, and executor.
- `src/web_server.cpp` - ESP32 web routes for upload, execution, manual movement, status, servo control, stop, and clear.
- `src/gcode_parser.cpp` - parser for supported G-code commands.
- `src/gcode_executor.cpp` - command queue execution, pen state handling, segmentation, bounds checks, and motion dispatch.
- `src/kinematics.cpp` - cable-length calculations and conversion from target point to motor step plan.
- `src/motor_control.cpp` - synchronized half-step motor execution.
- `src/servo_control.cpp` - pen servo control.
- `include/config.h` - workspace, paper model, motor pins, motor calibration defaults, Wi-Fi settings, and motion constants.

Responsibilities:

- Run the ESP32 access point and device web UI.
- Accept G-code uploads.
- Parse and queue supported commands.
- Execute pen up/down commands.
- Segment long moves for smoother motion.
- Convert target coordinates to cable-length deltas.
- Step four motors in sync.

## End-to-End Workflow

1. Start the Python bridge server.
2. Open the local browser UI.
3. Upload an image.
4. Choose a preset or processing parameters.
5. Process the image into paths.
6. Preview and validate the extracted paths.
7. Generate G-code.
8. Upload the G-code to the ESP32.
9. Execute the queued drawing from the ESP32.
10. Validate output on paper and calibrate hardware as needed.

## Project Structure

```text
.
|-- bridge_server.py          # Local Python HTTP bridge and API
|-- image_processor.py        # Image-to-path processing
|-- path_optimizer.py         # Path cleanup and ordering
|-- preset_modes.py           # Processing presets
|-- web_handlers.py           # Python-side API logic
|-- gcode_exporter.py         # Export helpers
|-- requirements.txt          # Python dependencies
|-- platformio.ini            # ESP32 PlatformIO project config
|-- web/
|   `-- index.html            # Python-side browser UI
|-- include/
|   |-- config.h              # Hardware, workspace, and motion constants
|   |-- gcode_executor.h
|   |-- gcode_parser.h
|   |-- gcode_validator.h
|   |-- kinematics.h
|   |-- motor_control.h
|   |-- robot_state.h
|   |-- servo_control.h
|   `-- web_server.h
|-- src/
|   |-- main.cpp              # ESP32 firmware entry point
|   |-- gcode_executor.cpp
|   |-- gcode_parser.cpp
|   |-- kinematics.cpp
|   |-- motor_control.cpp
|   |-- servo_control.cpp
|   |-- web_server.cpp
|   `-- path_format.h         # Legacy/stale path contract header; not active in firmware build
`-- docs/
    |-- AGENTS.md
    |-- PROJECT_CONTEXT.md
    |-- TASKS.md
    |-- ARCHITECTURE.md
    |-- HARDWARE_MODEL.md
    `-- KNOWN_ISSUES.md
```

## Setup

### Python Side

Requirements:

- Python 3
- OpenCV and NumPy from `requirements.txt`

Install dependencies:

```bash
pip install -r requirements.txt
```

Start the local bridge server:

```bash
python bridge_server.py
```

Open:

```text
http://127.0.0.1:8080
```

The bridge server exposes:

- `GET /` - local processing UI
- `GET /api/presets` - available processing presets
- `POST /api/process-image` - image-to-path processing
- `GET /api/preview` - preview path data
- `GET /api/validate-paths` - path validation summary
- `POST /api/generate-gcode` - G-code generation
- `POST /api/upload-to-esp` - upload generated G-code to an ESP32 URL

### ESP32 Firmware

Requirements:

- PlatformIO
- ESP32 board configured by `platformio.ini`
- Arduino framework
- `madhephaestus/ESP32Servo`

Build firmware:

```bash
pio run
```

Upload firmware:

```bash
pio run --target upload
```

Open serial monitor:

```bash
pio device monitor
```

The firmware starts a Wi-Fi access point using values from `include/config.h`:

```text
SSID: CableRobot_Hotspot
Password: robot123
```

After connecting to the ESP32 access point, use the IP printed in the serial monitor to access the device web interface.

## Firmware Build Flow

1. Configure hardware constants in `include/config.h`.
2. Build with `pio run`.
3. Upload with `pio run --target upload`.
4. Monitor boot logs with `pio device monitor`.
5. Confirm the ESP32 access point starts.
6. Upload G-code through the device UI or through the Python bridge.
7. Execute only after the robot is mechanically safe and calibrated.

## Testing

Local software checks:

```bash
python -m py_compile image_processor.py preset_modes.py web_handlers.py path_optimizer.py bridge_server.py gcode_exporter.py
pio run
```

Recommended hardware validation order:

1. Pen up/down check.
2. Manual movement with pen up.
3. Short straight line.
4. Square.
5. Circle.
6. Simple outline or signature.
7. Full image-to-drawing comparison.

Do not treat a successful firmware build as proof that motor directions, steps/mm, cable tension, or drawing accuracy are correct.

## Limitations

- Motor direction signs are hardware-dependent and must be verified on the physical robot.
- `MOTOR_STEPS_PER_MM` values are starting calibration values, not proven final values.
- Anchor offsets in `include/config.h` are configurable assumptions around the paper.
- The firmware supports a small G-code subset: `G0`, `G1`, `M3`, `M5`; `G21` and `G90` are accepted as no-op setup commands.
- Heavy image processing intentionally runs on the Python/laptop side, not on the ESP32.
- Some files under `docs/` are historical copies and may describe older implementation stages.
- `src/path_format.h` appears to be a legacy path contract header and is not part of the active firmware include path.

## Roadmap

- Add explicit calibration workflow for motor direction, steps/mm, and anchor offsets.
- Add hardware-backed test drawings and expected results.
- Improve generated G-code preview and bounds reporting.
- Add automated tests for segmentation and G-code generation behavior.
- Add clearer device status reporting during long executions.
- Document known-good hardware wiring and pulley configuration after physical validation.

## Documentation

Primary engineering docs:

- `docs/PROJECT_CONTEXT.md`
- `docs/TASKS.md`
- `docs/ARCHITECTURE.md`
- `docs/HARDWARE_MODEL.md`
- `docs/KNOWN_ISSUES.md`

When docs conflict with active code, prefer the active code. The current architecture keeps Python-side processing separate from ESP32-side execution.

## Demo

Demo media is not included yet.

Suggested placeholders:

- Photo of the assembled cable-driven robot.
- Short video of line, square, and circle validation.
- Image-to-drawing comparison from the Python UI through ESP32 execution.

## License

No license file is currently included in this repository. Add a license before distributing or accepting external contributions.

</details>

<details>
<summary><strong>device_code/README.md</strong></summary>

# Device Code

الفولدر ده فيه كل ما يخص كود الجهاز:

```text
device_code/
├─ firmware/       كود ESP32 PlatformIO
├─ python_tools/   أدوات Python القديمة/الإضافية لمعالجة الصور أو التجارب
└─ docs/           توثيق الجهاز والملاحظات
```

النسخة الأساسية للموبايل دلوقتي لا تحتاج Python server. التطبيق يحول الصورة إلى G-code محليًا داخل Flutter ثم يرفع الـ G-code مباشرة إلى ESP32.

استخدم `firmware/` لرفع كود الجهاز، و`python_tools/` اختياري لو محتاج تجارب معالجة صور خارج التطبيق.

</details>

<details>
<summary><strong>FIRMWARE_APP_FINAL_FIX_NOTES.md</strong></summary>

# Final Firmware + App G-code Fix Notes

This package applies the two remaining fixes identified after comparing the new mobile app pipeline with the previous Python/Web G-code pipeline.

## 1. Firmware segment interpolation made explicit

Files changed:

- `device_code/firmware/include/gcode_executor.h`
- `device_code/firmware/src/gcode_executor.cpp`

The executor now stores the start point of each long G-code move in:

- `segmentStartX`
- `segmentStartY`

Intermediate segment points are generated with a direct linear interpolation factor:

```cpp
const float t = static_cast<float>(segmentIndex + 1) / static_cast<float>(segmentCount);
outX = segmentStartX + (segmentTargetX - segmentStartX) * t;
outY = segmentStartY + (segmentTargetY - segmentStartY) * t;
```

This makes the motion logic easier to verify and avoids any ambiguity caused by using the robot's continuously changing current position during segmentation.

## 2. App Safe Area fitting now fills the safe rectangle

File changed:

- `app/lib/services/image_to_gcode_converter.dart`

The mobile image-to-G-code converter no longer caps scale at `1.0` during safe-area fitting. Small drawings can now scale up to fill the user's selected safe area while still being clamped inside the safe rectangle.

Old behavior:

```dart
final scale = math.min(settings.safeWidthMm / drawW, settings.safeHeightMm / drawH);
final safeScale = math.min(scale, 1.0);
```

New behavior:

```dart
final safeScale = math.min(settings.safeWidthMm / drawW, settings.safeHeightMm / drawH);
```

## Notes

- The app still generates contour/vector G-code rather than raster scan-line G-code.
- This reduces unnecessary pen up/down operations.
- Safe Area default remains aligned with firmware A4 settings: `X=20`, `Y=20`, `Width=170`, `Height=257`.
- Firmware coordinate transform remains disabled (`scale=1`, `offset=0`) so the ESP32 executes the uploaded app coordinates directly.

</details>

<details>
<summary><strong>OLD_GCODE_ORDER_MATCH_FIX.md</strong></summary>

# Old G-code Order Match Fix

This update keeps the existing Safe Area and UI features, but changes the mobile image-to-G-code converter so closed contours are normalized to match the old working Python/OpenCV output more closely.

## What changed

- Closed contours are forced to the old clockwise direction in image/workspace coordinates.
- Each contour is rotated to start from the top-left discovered boundary region, similar to OpenCV `findContours` scan behavior.
- Safe Area mapping remains unchanged.
- G-code commands remain ESP-compatible: `M5`, `G0`, `M3`, `G1`, `M5`.

## Why

The previous pure-Dart contour tracer could generate the same shape in the opposite contour direction, for example:

```text
new: top-left -> top-right -> right side -> bottom -> left side
old: top-left -> left side -> bottom -> right side -> top
```

Both describe a similar contour visually, but the robot movement and pen behavior can look different. This patch makes the mobile output closer to the old working G-code.

</details>

<details>
<summary><strong>OLD_WORKING_PIPELINE_COMPARISON.md</strong></summary>

# Old Working Pipeline Comparison Fix

This version compares the old working Python/firmware project with the Flutter app pipeline and keeps the parts that were proven to draw correctly.

## What was restored from the old working firmware

- `device_code/firmware/src/gcode_executor.cpp`
- `device_code/firmware/include/gcode_executor.h`

The executor was restored to the old incremental segmentation behavior. The previous and new interpolation formulas are mathematically close, but restoring the known-working executor removes firmware behavior as a variable while debugging real hardware drawing quality.

## What was changed in Flutter G-code generation

The Flutter converter now matches the old Python/OpenCV pipeline more closely:

1. Resize image using the A4 workspace aspect ratio.
2. Convert to grayscale.
3. Apply a light 5x5 Gaussian blur before thresholding, matching the old `cv2.GaussianBlur` behavior.
4. Threshold black strokes as foreground by default.
5. Morphological close to reconnect tiny gaps.
6. Extract contour-style paths.
7. Simplify closed paths as closed rings instead of treating the contour as a normal open line.
8. Apply safe-area fitting using the old Python scale cap (`scale <= 1.0`) while still supporting the user-entered safe rectangle.
9. Generate ESP-compatible `M5`, `G0`, `M3`, `G1`, `M5` commands.

## Why this matters

The old Python pipeline used OpenCV contours, not raster scan lines. The Flutter pipeline must therefore avoid generating thousands of horizontal line strokes. It should generate a few contour paths so pen-up / pen-down operations are minimized.

## Hardware note

If travel lines are still drawn between separate shapes, the G-code is usually not the root cause. That means `M5` is not physically lifting the pen enough, so `SERVO_UP_ANGLE`, `SERVO_DOWN_ANGLE`, or pen pressure must be calibrated.

</details>

<details>
<summary><strong>PERFORMANCE_FIX_NOTES.md</strong></summary>

# Spidy Draw Performance Fix

This build focuses on making manual robot control smoother on real Android phones.

## What changed

- Manual movement no longer uses the global loading lock.
- Arrow buttons stay responsive while ESP32 is replying.
- Only one `/move` HTTP request is sent at a time; rapid taps keep the latest direction only.
- Long press on any arrow now sends repeated movement commands for smoother calibration.
- Status polling is paused during manual movement to avoid fighting the movement requests.
- Status UI no longer rebuilds every poll when nothing changed.
- G-code preview is isolated with `RepaintBoundary` to reduce expensive repaints.
- Manual movement timeout reduced to 2 seconds.
- Status polling interval increased from 2 seconds to 4 seconds.

## How to use

- Tap arrow once = one movement step.
- Hold arrow = continuous smooth movement.
- Release arrow = app refreshes robot status automatically.

</details>

<details>
<summary><strong>PYTHON_EQUIVALENT_GCODE_NOTES.md</strong></summary>

# Python-equivalent Image to G-code update

This version changes the Flutter image converter from raster scan-lines to a contour/vector pipeline that mirrors the original Python project:

```text
Image
→ resize to A4 workspace aspect ratio 210×297
→ grayscale + threshold
→ black-stroke foreground extraction like Python THRESH_BINARY_INV
→ morphology close
→ external contour extraction
→ remove duplicate points
→ Douglas-Peucker simplification
→ nearest-neighbor path ordering
→ fit into user Safe Area
→ G0/G1/M3/M5 G-code
```

## Safe Area

The app now keeps the same firmware coordinate system:

```text
Workspace: 210 × 297 mm
Default Safe Area: X=20, Y=20, W=170, H=257
```

All generated G-code points are clamped inside the user-entered Safe Area.

## Pen up/down reduction

The old raster method produced many short horizontal lines, so it generated many M3/M5 commands. This update draws contours as continuous paths, so each contour normally uses:

```gcode
M5
G0 X.. Y..
M3
G1 X.. Y..
G1 X.. Y..
M5
```

That reduces the number of pen up/down operations and makes the G-code closer to the original Python output.

## UI mapping

The old `rowStepPx` setting is now used as path simplification tolerance:

```text
simplify_tolerance_mm = rowStepPx × 0.4
```

Default rowStepPx=2 means simplify_tolerance=0.8mm, matching the Python default.

</details>

<details>
<summary><strong>README.md</strong></summary>

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

</details>

<details>
<summary><strong>STABILITY_FIX_NOTES.md</strong></summary>

# Stability Fix v3

This version fixes the runtime error:

- `Cannot hit test a render box with no size`

Changes:

1. Removed `RefreshIndicator` from the dashboard body to avoid gesture/hit-test conflicts on some Android devices. Refresh is still available from the AppBar refresh button.
2. Made `WorkflowStepTile` use a fixed width and removed the unsafe `Spacer` pattern inside horizontally scrollable content.
3. Reduced dashboard rebuilds during manual movement. The app no longer calls `setState()` for every manual move step during long press.
4. Kept the smooth manual movement request queue from the performance build.

Run:

```powershell
cd D:\importent\Spidy-Draw-Final-Organized\app
flutter clean
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
flutter pub get
flutter run
```

</details>

<details>
<summary><strong>UI_SAFEAREA_PERFORMANCE_FIX_NOTES.md</strong></summary>

# UI + Safe Area UX Fix Notes

This update improves the mobile app UI/UX without changing the image-to-G-code conversion algorithm or the firmware G-code execution logic.

## What changed

- Safe Area presets now update the text fields immediately.
- Safe Area number fields now clamp to the real A4 workspace limits:
  - X: 0..210 mm
  - Y: 0..297 mm
  - Width: 10..210 mm
  - Height: 10..297 mm
- Added a small A4 visual preview showing the Safe Area rectangle on the paper.
- Added a visible processing banner while the app is analyzing the image and extracting contours.
- Cached G-code preview lines instead of splitting the full G-code text on every rebuild.
- Added a scrollbar to the G-code console preview.
- Added an uploaded state badge after successful upload to ESP.
- Added X+/Y+ labels under the manual movement buttons.
- Added status polling backoff after repeated offline failures.
- Added retry action on the connection screen after failed connection.
- Added zoom/pan support to the G-code path preview.
- Optimized `GcodePathPreview.shouldRepaint` to avoid unnecessary repainting.

## Important

The G-code generation logic was not changed in this update. This is a UI/UX and performance/stability update only.

</details>

