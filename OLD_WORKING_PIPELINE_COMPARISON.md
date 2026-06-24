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
