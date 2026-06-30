# Spidy-Draw — ESP32 Cable-Driven Drawing Robot

**Spidy-Draw** is a portable cable-driven drawing robot controlled by a Flutter mobile application and an ESP32-based firmware system. The application converts an image or camera photo into drawing paths, generates ESP-compatible G-code locally on the mobile device, uploads it directly to the ESP32, and controls the drawing process through synchronized stepper motors and a pen servo.

The project demonstrates an end-to-end embedded robotics workflow:

```text
Image / Camera Input
→ Mobile Image Processing
→ Path Extraction
→ Safe Area Mapping
→ ESP-Compatible G-code Generation
→ ESP32 Upload
→ Cable-Driven Drawing Execution
```

---

## 1. Project Overview

Spidy-Draw is designed as a practical robotic drawing system that combines mobile development, embedded systems, motion control, and digital image processing.

Unlike a traditional rigid XY plotter, Spidy-Draw uses a **cable-driven motion mechanism**. The ESP32 controls four stepper motors through a cable and pulley system, while a servo motor manages pen up/down movement.

The mobile application provides the main user interface for:

- Connecting to the ESP32 device.
- Selecting or capturing an image.
- Converting the image into G-code.
- Previewing the drawing path.
- Uploading the generated G-code to the ESP32.
- Running and controlling the drawing process.

---

## 2. Project Objectives

The main objectives of Spidy-Draw are:

- Build a portable robotic drawing system using ESP32.
- Convert user-selected images into drawable paths.
- Generate G-code directly on the mobile device.
- Control the robot wirelessly through a Flutter application.
- Support safe drawing boundaries to protect the workspace.
- Provide a clean and professional user experience for demonstration and real use.
- Create a modular project structure that separates the mobile app, firmware, and supporting tools.

---

## 3. Main Features

### Mobile Application

- Professional Flutter interface suitable for a graduation project presentation.
- Single ESP32 URL connection flow.
- Image selection from the gallery.
- Camera capture support.
- Local image-to-G-code conversion.
- G-code preview before uploading.
- User-editable Safe Drawing Area.
- A4 workspace support: `210 × 297 mm`.
- Direct G-code upload to ESP32.
- Robot control actions:
  - Run
  - Stop
  - Clear
  - Home
  - Pen Up
  - Pen Down
- Manual movement controls for calibration.
- Live ESP32 status polling.
- Smooth interaction on Android devices.

### ESP32 Firmware

- ESP32 web communication layer.
- G-code upload and execution.
- G-code parsing.
- Command queue management.
- Four stepper motor coordination.
- Cable-driven motion handling.
- Servo-based pen control.
- Device-side endpoints for mobile control.
- Movement segmentation for smoother lines.

### Supporting Tools

The project also includes optional supporting tools for image-processing experiments and development verification. The final mobile workflow does not require running a separate Python server during normal operation.

---

## 4. System Architecture

Spidy-Draw is organized into three main layers:

```text
┌──────────────────────────┐
│ Flutter Mobile App        │
│ Image processing + UI     │
└─────────────┬────────────┘
              │ G-code upload / control requests
              ▼
┌──────────────────────────┐
│ ESP32 Firmware            │
│ G-code queue + execution  │
└─────────────┬────────────┘
              │ Motor and servo signals
              ▼
┌──────────────────────────┐
│ Cable-Driven Robot        │
│ Drawing on physical paper │
└──────────────────────────┘
```

### Mobile App Responsibilities

- User interface.
- ESP32 connection management.
- Image input.
- Image preprocessing.
- Path extraction.
- Safe Area mapping.
- G-code generation.
- G-code upload.
- Manual and automatic robot controls.

### Firmware Responsibilities

- Receive commands from the mobile app.
- Accept uploaded G-code.
- Parse supported G-code commands.
- Manage execution state.
- Control the pen servo.
- Coordinate stepper motors.
- Execute drawing paths on the physical robot.

---

## 5. Project Structure

```text
Spidy-Draw/
├─ app/                         Flutter mobile application
│  ├─ lib/                      Main Dart source code
│  ├─ assets/                   Application assets
│  ├─ android/                  Android platform files
│  ├─ web/                      Flutter web support
│  ├─ sample_gcode/             App-level G-code samples
│  └─ scripts/                  Helper scripts
│
├─ device_code/                 ESP32 firmware and supporting tools
│  ├─ firmware/                 PlatformIO ESP32 firmware
│  │  ├─ include/               Firmware configuration and header files
│  │  ├─ src/                   Main C++ firmware source code
│  │  ├─ web/                   ESP32 web resources
│  │  └─ platformio.ini         PlatformIO board configuration
│  │
│  └─ python_tools/             Optional development and testing utilities
│
├─ sample_gcode/                G-code samples for testing
├─ scripts/                     Project helper scripts
├─ README.md                    Main project documentation
└─ .gitignore
```

---

## 6. Requirements

### Mobile Application

- Flutter SDK compatible with Dart `>=3.4.0 <4.0.0`.
- Android device or emulator.
- Network access to the ESP32 hotspot or the same local network.
- Flutter dependencies listed in:

```text
app/pubspec.yaml
```

Current application package information:

```yaml
name: spidy_draw
description: ESP32 controller app for the Spidy-Draw cable-driven robot with local image-to-G-code conversion.
version: 1.3.0+4
```

### ESP32 Firmware

- PlatformIO.
- ESP32 board compatible with the configured environment.
- Arduino framework.
- Required library:
  - `madhephaestus/ESP32Servo`

Firmware configuration file:

```text
device_code/firmware/platformio.ini
```

---

## 7. Running the Mobile Application

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

Expected APK output:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

---

## 8. Uploading the Firmware to ESP32

From the project root:

```bash
cd device_code/firmware
pio run
pio run --target upload
```

To open the serial monitor:

```bash
pio device monitor
```

Default Wi-Fi configuration is defined in:

```text
device_code/firmware/include/config.h
```

Default ESP32 hotspot settings:

```cpp
AP_SSID = "CableRobot_Hotspot"
AP_PASSWORD = "robot123"
```

---

## 9. ESP32 Communication Endpoints

The Flutter application communicates with the ESP32 using one base URL.

Typical ESP32 URL examples:

```text
http://192.168.4.1
http://192.168.1.50
```

Supported endpoints:

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

### Endpoint Purpose

| Endpoint | Purpose |
|---|---|
| `/status` | Reads current robot status |
| `/upload-text` | Uploads generated G-code text |
| `/execute` | Starts executing uploaded G-code |
| `/stop` | Stops the current operation |
| `/clear` | Clears the current G-code queue |
| `/home` | Sends the robot to its home position |
| `/servo?pos=0\|1` | Controls pen up/down |
| `/move?angle=...&repeats=...` | Performs manual movement for calibration |

---

## 10. Safe Drawing Area

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

The Safe Area allows the user to define the drawing boundaries inside the paper. Generated G-code points are mapped and clamped inside this area to help prevent drawing outside the selected workspace.

---

## 11. Image-to-G-code Pipeline

The mobile application converts the selected image into ESP-compatible G-code using a contour-based workflow:

```text
Image
→ Resize to workspace aspect ratio
→ Convert to grayscale
→ Apply threshold
→ Extract foreground strokes
→ Clean small gaps
→ Extract contours
→ Remove duplicate points
→ Simplify paths
→ Order paths
→ Map to Safe Area
→ Generate G-code
```

Generated commands follow a simple ESP-compatible format:

```gcode
M5
G0 X.. Y..
M3
G1 X.. Y..
M5
```

Command meaning:

| Command | Meaning |
|---|---|
| `M5` | Pen up |
| `M3` | Pen down |
| `G0` | Move without drawing |
| `G1` | Move while drawing |

---

## 12. Hardware Components

The system is built around:

- ESP32 microcontroller.
- Four stepper motors.
- Motor drivers.
- One servo motor.
- Cable and pulley motion system.
- Pen holder mechanism.
- Drawing surface.
- Power supply.

### Motion Concept

The robot uses cable-driven movement. The firmware coordinates motor motion to move the pen holder across the drawing area. Accurate drawing depends on correct calibration of cable geometry, motor direction, and steps-per-millimeter values.

---

## 13. Demonstration Flow

Recommended sequence for the graduation presentation:

1. Power on the ESP32 robot.
2. Connect the phone to the ESP32 hotspot or the same local network.
3. Open the Spidy-Draw mobile application.
4. Enter the ESP32 URL.
5. Check live robot status.
6. Select an image or capture a photo.
7. Adjust conversion settings if needed.
8. Set the Safe Drawing Area.
9. Preview the generated drawing path.
10. Upload the G-code to the ESP32.
11. Start drawing.
12. Demonstrate Stop, Clear, Home, Manual Move, Pen Up, and Pen Down controls.

---

## 14. Testing and Calibration

Before presenting a complex drawing, test the robot in this order:

```text
1. Pen up/down test
2. Manual movement test
3. Straight line
4. Square
5. Circle
6. Simple logo or icon
7. Final demonstration image
```

Recommended calibration checks:

- Motor direction.
- Steps-per-millimeter.
- Cable tension.
- Workspace dimensions.
- Pen pressure.
- Safe Area values.
- G-code coordinate mapping.

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

### Android device cannot connect to ESP32

Check that:

- The phone is connected to the ESP32 hotspot or the same network.
- The ESP32 IP address is correct.
- The URL starts with `http://`.
- The ESP32 firmware is running.
- The application has internet/network permission.

Android permissions used by the app:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CAMERA" />
```

### Firmware upload fails

Run:

```bash
cd device_code/firmware
pio run
pio run --target upload
```

Check that:

- The USB cable supports data transfer.
- The correct board and port are selected.
- The serial monitor is closed during upload.
- ESP32 drivers are installed.

### Drawing output needs adjustment

Review:

- Motor direction.
- Steps-per-millimeter calibration.
- Cable tension.
- Workspace dimensions.
- Safe Area settings.
- Pen height and pressure.
- G-code preview before execution.

---

## 16. Final Submission Checklist

Before submitting or presenting the project:

- [ ] Run `flutter analyze`.
- [ ] Run the app on a real Android phone.
- [ ] Build the release APK.
- [ ] Upload the ESP32 firmware successfully.
- [ ] Connect the app to the ESP32 device.
- [ ] Test status, upload, run, stop, clear, home, and servo controls.
- [ ] Test manual movement.
- [ ] Validate line, square, and circle drawing.
- [ ] Prepare a simple final demo image.
- [ ] Confirm that this `README.md` is placed in the project root.
- [ ] Keep the submitted package clean from build caches and temporary files.

---

## Project Status

Spidy-Draw is prepared as a complete graduation project package that combines a Flutter mobile application, ESP32 firmware, and a cable-driven drawing robot mechanism. The project is structured for demonstration, further development, and practical hardware calibration.
