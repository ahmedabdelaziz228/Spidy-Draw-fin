class GcodeSegment {
  const GcodeSegment({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });

  final double startX;
  final double startY;
  final double endX;
  final double endY;

  factory GcodeSegment.fromJson(Map<String, dynamic> json) {
    return GcodeSegment(
      startX: _toDouble(json['startX']),
      startY: _toDouble(json['startY']),
      endX: _toDouble(json['endX']),
      endY: _toDouble(json['endY']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startX': startX,
      'startY': startY,
      'endX': endX,
      'endY': endY,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GeneratedGcode {
  const GeneratedGcode({
    required this.gcode,
    required this.segments,
    required this.commandCount,
    required this.segmentCount,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.rasterWidth,
    required this.rasterHeight,
    required this.safeXmm,
    required this.safeYmm,
    required this.safeWidthMm,
    required this.safeHeightMm,
    required this.usedWidthMm,
    required this.usedHeightMm,
    required this.truncated,
  });

  final String gcode;
  final List<GcodeSegment> segments;
  final int commandCount;
  final int segmentCount;
  final int sourceWidth;
  final int sourceHeight;
  final int rasterWidth;
  final int rasterHeight;
  final double safeXmm;
  final double safeYmm;
  final double safeWidthMm;
  final double safeHeightMm;
  final double usedWidthMm;
  final double usedHeightMm;
  final bool truncated;

  factory GeneratedGcode.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    return GeneratedGcode(
      gcode: json['gcode']?.toString() ?? '',
      segments: rawSegments is List
          ? rawSegments
              .whereType<Map>()
              .map((item) =>
                  GcodeSegment.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const [],
      commandCount: _toInt(json['commandCount']),
      segmentCount: _toInt(json['segmentCount']),
      sourceWidth: _toInt(json['sourceWidth']),
      sourceHeight: _toInt(json['sourceHeight']),
      rasterWidth: _toInt(json['rasterWidth']),
      rasterHeight: _toInt(json['rasterHeight']),
      safeXmm: _toDouble(json['safeXmm']),
      safeYmm: _toDouble(json['safeYmm']),
      safeWidthMm: _toDouble(json['safeWidthMm']),
      safeHeightMm: _toDouble(json['safeHeightMm']),
      usedWidthMm: _toDouble(json['usedWidthMm']),
      usedHeightMm: _toDouble(json['usedHeightMm']),
      truncated: json['truncated'] == true ||
          json['truncated']?.toString().toLowerCase() == 'true',
    );
  }

  bool get isEmpty => gcode.trim().isEmpty || segmentCount == 0;

  String get summary {
    final clipped = truncated ? ' — تم قصه عند الحد الآمن' : '';
    return '$segmentCount Segment / $commandCount أمر / رسم ${usedWidthMm.toStringAsFixed(1)}×${usedHeightMm.toStringAsFixed(1)} mm داخل Safe Area ${safeWidthMm.toStringAsFixed(1)}×${safeHeightMm.toStringAsFixed(1)} mm$clipped';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ImageGcodeSettings {
  const ImageGcodeSettings({
    required this.safeXmm,
    required this.safeYmm,
    required this.safeWidthMm,
    required this.safeHeightMm,
    required this.rasterWidthPx,
    required this.threshold,
    required this.rowStepPx,
    required this.minRunPx,
    required this.maxCommands,
    required this.invert,
  });

  final double safeXmm;
  final double safeYmm;
  final double safeWidthMm;
  final double safeHeightMm;
  final int rasterWidthPx;
  final int threshold;
  final int rowStepPx;
  final int minRunPx;
  final int maxCommands;
  final bool invert;

  Map<String, dynamic> toJson() {
    return {
      'safeXmm': safeXmm,
      'safeYmm': safeYmm,
      'safeWidthMm': safeWidthMm,
      'safeHeightMm': safeHeightMm,
      'rasterWidthPx': rasterWidthPx,
      'threshold': threshold,
      'rowStepPx': rowStepPx,
      'minRunPx': minRunPx,
      'maxCommands': maxCommands,
      'invert': invert,
    };
  }

  factory ImageGcodeSettings.fromJson(Map<String, dynamic> json) {
    return ImageGcodeSettings(
      safeXmm: _toDouble(json['safeXmm'], fallback: 20),
      safeYmm: _toDouble(json['safeYmm'], fallback: 20),
      safeWidthMm: _toDouble(json['safeWidthMm'], fallback: 170),
      safeHeightMm: _toDouble(json['safeHeightMm'], fallback: 257),
      rasterWidthPx: _toInt(json['rasterWidthPx'], fallback: 220),
      threshold: _toInt(json['threshold'], fallback: 145),
      rowStepPx: _toInt(json['rowStepPx'], fallback: 2),
      minRunPx: _toInt(json['minRunPx'], fallback: 2),
      maxCommands: _toInt(json['maxCommands'], fallback: 5500),
      invert: json['invert'] == true ||
          json['invert']?.toString().toLowerCase() == 'true',
    );
  }

  static double _toDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
