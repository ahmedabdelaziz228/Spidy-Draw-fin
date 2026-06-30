import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/generated_gcode.dart';
import '../theme/app_theme.dart';

class GcodePathPreview extends StatelessWidget {
  const GcodePathPreview({
    super.key,
    required this.segments,
    required this.emptyText,
    this.safeXmm,
    this.safeYmm,
    this.safeWidthMm,
    this.safeHeightMm,
  });

  final List<GcodeSegment> segments;
  final String emptyText;
  final double? safeXmm;
  final double? safeYmm;
  final double? safeWidthMm;
  final double? safeHeightMm;

  @override
  Widget build(BuildContext context) {
    final hasPreview = segments.isNotEmpty;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                  child: CustomPaint(painter: _PreviewBackgroundPainter())),
              Positioned.fill(
                child: hasPreview
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final width = math.max(1.0, constraints.maxWidth);
                          final height = math.max(1.0, constraints.maxHeight);
                          return InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 6.0,
                            clipBehavior: Clip.hardEdge,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: SizedBox(
                              width: width,
                              height: height,
                              child: CustomPaint(
                                painter: _GcodePathPainter(
                                  segments: segments,
                                  safeXmm: safeXmm,
                                  safeYmm: safeYmm,
                                  safeWidthMm: safeWidthMm,
                                  safeHeightMm: safeHeightMm,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.22)),
                                ),
                                child: const Icon(Icons.polyline_rounded,
                                    color: AppTheme.primary, size: 30),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                emptyText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontWeight: FontWeight.w800,
                                    height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasPreview
                            ? Icons.zoom_out_map_rounded
                            : Icons.hourglass_empty_rounded,
                        size: 15,
                        color: hasPreview ? AppTheme.success : AppTheme.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasPreview
                            ? '${segments.length} segments • zoom'
                            : 'Preview',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x330EA5E9), Color(0x11000000), Color(0x22A855F7)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.22)
      ..strokeWidth = 0.7;
    const step = 24.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GcodePathPainter extends CustomPainter {
  const _GcodePathPainter({
    required this.segments,
    this.safeXmm,
    this.safeYmm,
    this.safeWidthMm,
    this.safeHeightMm,
  });

  final List<GcodeSegment> segments;
  final double? safeXmm;
  final double? safeYmm;
  final double? safeWidthMm;
  final double? safeHeightMm;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty || size.width <= 0 || size.height <= 0) return;

    final sx = safeXmm;
    final sy = safeYmm;
    final sw = safeWidthMm;
    final sh = safeHeightMm;
    final hasSafeArea = sx != null &&
        sy != null &&
        sw != null &&
        sh != null &&
        sw > 0 &&
        sh > 0;

    var minX = hasSafeArea ? sx : double.infinity;
    var minY = hasSafeArea ? sy : double.infinity;
    var maxX = hasSafeArea ? sx + sw : -double.infinity;
    var maxY = hasSafeArea ? sy + sh : -double.infinity;

    if (!hasSafeArea) {
      for (final s in segments) {
        minX = math.min(minX, math.min(s.startX, s.endX));
        minY = math.min(minY, math.min(s.startY, s.endY));
        maxX = math.max(maxX, math.max(s.startX, s.endX));
        maxY = math.max(maxY, math.max(s.startY, s.endY));
      }
    }

    if (![minX, minY, maxX, maxY].every((value) => value.isFinite)) return;

    final contentWidth = math.max(1.0, maxX - minX);
    final contentHeight = math.max(1.0, maxY - minY);
    const padding = 22.0;
    final drawableWidth = math.max(1.0, size.width - padding * 2);
    final drawableHeight = math.max(1.0, size.height - padding * 2);
    final scaleX = drawableWidth / contentWidth;
    final scaleY = drawableHeight / contentHeight;
    final scale = math.max(0.01, math.min(scaleX, scaleY));

    final usedWidth = contentWidth * scale;
    final usedHeight = contentHeight * scale;
    final dx = (size.width - usedWidth) / 2;
    final dy = (size.height - usedHeight) / 2;

    Offset mapPoint(double x, double y) {
      return Offset(
        dx + ((x - minX) * scale),
        dy + ((y - minY) * scale),
      );
    }

    final safePaint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final safeFillPaint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    if (hasSafeArea) {
      final safeRect =
          Rect.fromPoints(mapPoint(sx, sy), mapPoint(sx + sw, sy + sh));
      final rrect =
          RRect.fromRectAndRadius(safeRect, const Radius.circular(12));
      canvas.drawRRect(rrect, safeFillPaint);
      canvas.drawRRect(rrect, safePaint);

      for (var i = 1; i < 4; i++) {
        final x = safeRect.left + (safeRect.width * i / 4);
        canvas.drawLine(
            Offset(x, safeRect.top), Offset(x, safeRect.bottom), gridPaint);
        final y = safeRect.top + (safeRect.height * i / 4);
        canvas.drawLine(
            Offset(safeRect.left, y), Offset(safeRect.right, y), gridPaint);
      }
    } else {
      final borderPaint = Paint()
        ..color = AppTheme.border.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(dx, dy, usedWidth, usedHeight),
            const Radius.circular(12)),
        borderPaint,
      );
    }

    final pathPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.96)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.9, math.min(2.4, scale * 0.2));

    final shadowPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.16)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = pathPaint.strokeWidth + 3.0;

    for (final s in segments) {
      final start = mapPoint(s.startX, s.startY);
      final end = mapPoint(s.endX, s.endY);
      canvas.drawLine(start, end, shadowPaint);
      canvas.drawLine(start, end, pathPaint);
    }

    if (hasSafeArea) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text:
              'SAFE AREA  ${sw.toStringAsFixed(0)}×${sh.toStringAsFixed(0)} mm',
          style: TextStyle(
            color: AppTheme.secondary.withValues(alpha: 0.95),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(dx + 10, dy + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _GcodePathPainter oldDelegate) {
    return oldDelegate.segments.length != segments.length ||
        oldDelegate.safeXmm != safeXmm ||
        oldDelegate.safeYmm != safeYmm ||
        oldDelegate.safeWidthMm != safeWidthMm ||
        oldDelegate.safeHeightMm != safeHeightMm;
  }
}
