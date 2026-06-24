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
