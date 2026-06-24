import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/generated_gcode.dart';

class ImageToGcodeException implements Exception {
  const ImageToGcodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageToGcodeConverter {
  const ImageToGcodeConverter._();

  static Future<GeneratedGcode> convert({
    required Uint8List imageBytes,
    required ImageGcodeSettings settings,
  }) async {
    final result = await compute(_convertImageToGcodeTask, {
      'bytes': imageBytes,
      'settings': settings.toJson(),
    });

    return GeneratedGcode.fromJson(Map<String, dynamic>.from(result));
  }
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(_Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt((dx * dx) + (dy * dy));
  }
}

class _VectorPath {
  _VectorPath({required this.points, required this.closed});

  List<_Point> points;
  final bool closed;
  double lengthMm = 0;

  void calculateLength() {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    if (closed && points.length > 2 && points.last.distanceTo(points.first) > 1e-6) {
      total += points.last.distanceTo(points.first);
    }
    lengthMm = total;
  }
}

class _FitTransform {
  const _FitTransform({required this.scale, required this.offsetX, required this.offsetY});

  final double scale;
  final double offsetX;
  final double offsetY;
}

// These values intentionally mirror the Python/OpenCV pipeline that was already
// used in the original device project: A4 workspace, threshold/invert,
// morphology close, contour extraction, Douglas-Peucker simplification,
// nearest-neighbor path ordering, then simple ESP-compatible G-code.
const double _workspaceWidthMm = 210.0;
const double _workspaceHeightMm = 297.0;
const double _minAreaPx = 8.0;
const double _minPointDistanceMm = 0.25;
const double _minPathLengthMm = 1.0;
const int _morphKernel = 3;
const int _maxPreviewSegments = 2600;

const List<List<int>> _dirs8 = [
  [1, 0],
  [1, 1],
  [0, 1],
  [-1, 1],
  [-1, 0],
  [-1, -1],
  [0, -1],
  [1, -1],
];

Map<String, dynamic> _convertImageToGcodeTask(Map<String, dynamic> args) {
  final bytes = args['bytes'];
  if (bytes is! Uint8List || bytes.isEmpty) {
    throw const ImageToGcodeException('الصورة فاضية أو غير مقروءة');
  }

  final settings = ImageGcodeSettings.fromJson(
    Map<String, dynamic>.from(args['settings'] as Map),
  );

  if (settings.safeWidthMm < 10 || settings.safeHeightMm < 10) {
    throw const ImageToGcodeException('Safe Area صغيرة جدًا. خلي العرض والارتفاع أكبر من 10 mm.');
  }
  if (settings.safeXmm < 0 || settings.safeYmm < 0) {
    throw const ImageToGcodeException('بداية Safe Area لازم تكون صفر أو أكبر.');
  }
  if (settings.safeXmm + settings.safeWidthMm > _workspaceWidthMm + 0.001 ||
      settings.safeYmm + settings.safeHeightMm > _workspaceHeightMm + 0.001) {
    throw const ImageToGcodeException('Safe Area خارج مساحة A4: الحد الأقصى X=210mm و Y=297mm.');
  }

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const ImageToGcodeException('نوع الصورة غير مدعوم');
  }

  final sourceWidth = decoded.width;
  final sourceHeight = decoded.height;

  // Match the old Python processor: processing_height = width * 297 / 210.
  final processingWidth = settings.rasterWidthPx.clamp(80, 512).toInt();
  final processingHeight = math.max(
    1,
    (processingWidth * _workspaceHeightMm / _workspaceWidthMm).round(),
  );

  final resized = img.copyResize(
    decoded,
    width: processingWidth,
    height: processingHeight,
    interpolation: img.Interpolation.average,
  );

  var binary = _thresholdImage(
    resized,
    threshold: settings.threshold.clamp(0, 255).toInt(),
    blackStrokes: settings.invert,
  );

  if (_morphKernel > 1) {
    binary = _morphClose(binary, processingWidth, processingHeight);
  }

  // The old Python default simplify_tolerance was 0.8mm.
  // In the UI this is controlled by the old rowStep slider for compatibility.
  final simplifyToleranceMm = settings.rowStepPx.clamp(1, 8).toDouble() * 0.4;

  var paths = _extractContourPaths(
    binary,
    processingWidth,
    processingHeight,
    _workspaceWidthMm,
    _workspaceHeightMm,
    simplifyToleranceMm,
  );

  if (paths.isEmpty) {
    throw const ImageToGcodeException('الصورة لم تنتج Contours. جرّب Threshold أو غيّر Black strokes/White strokes أو استخدم صورة أوضح.');
  }

  final fit = _fitToSafeArea(paths, settings);
  paths = _transformPathsToSafeArea(paths, settings, fit);
  paths = _optimizePaths(paths, startPoint: _Point(settings.safeXmm, settings.safeYmm));

  final generated = _generateGcode(paths, settings);

  return {
    'gcode': generated.gcode,
    'segments': generated.segments,
    'commandCount': generated.commandCount,
    'segmentCount': generated.segmentCount,
    'sourceWidth': sourceWidth,
    'sourceHeight': sourceHeight,
    'rasterWidth': processingWidth,
    'rasterHeight': processingHeight,
    'safeXmm': settings.safeXmm,
    'safeYmm': settings.safeYmm,
    'safeWidthMm': settings.safeWidthMm,
    'safeHeightMm': settings.safeHeightMm,
    'usedWidthMm': generated.usedWidthMm,
    'usedHeightMm': generated.usedHeightMm,
    'truncated': generated.truncated,
  };
}

List<Uint8List> _thresholdImage(
  img.Image image, {
  required int threshold,
  required bool blackStrokes,
}) {
  final rows = List<Uint8List>.generate(image.height, (_) => Uint8List(image.width));

  for (var y = 0; y < image.height; y++) {
    final row = rows[y];
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final alpha = pixel.a.toDouble();
      if (alpha < 20) {
        row[x] = 0;
        continue;
      }

      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      final luma = (0.299 * r) + (0.587 * g) + (0.114 * b);

      // Python equivalent:
      //   invert=True  -> cv2.THRESH_BINARY_INV -> black drawing becomes foreground.
      //   invert=False -> cv2.THRESH_BINARY     -> white drawing becomes foreground.
      final foreground = blackStrokes ? luma < threshold : luma >= threshold;
      row[x] = foreground ? 1 : 0;
    }
  }

  return rows;
}

List<Uint8List> _morphClose(List<Uint8List> source, int width, int height) {
  return _erode(_dilate(source, width, height), width, height);
}

List<Uint8List> _dilate(List<Uint8List> source, int width, int height) {
  final output = List<Uint8List>.generate(height, (_) => Uint8List(width));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var value = 0;
      for (var dy = -1; dy <= 1 && value == 0; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= width) continue;
          if (source[ny][nx] == 1) {
            value = 1;
            break;
          }
        }
      }
      output[y][x] = value;
    }
  }
  return output;
}

List<Uint8List> _erode(List<Uint8List> source, int width, int height) {
  final output = List<Uint8List>.generate(height, (_) => Uint8List(width));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var value = 1;
      for (var dy = -1; dy <= 1 && value == 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= height) {
          value = 0;
          break;
        }
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= width || source[ny][nx] == 0) {
            value = 0;
            break;
          }
        }
      }
      output[y][x] = value;
    }
  }
  return output;
}

List<_VectorPath> _extractContourPaths(
  List<Uint8List> binary,
  int width,
  int height,
  double workspaceWidthMm,
  double workspaceHeightMm,
  double simplifyToleranceMm,
) {
  final visited = List<Uint8List>.generate(height, (_) => Uint8List(width));
  final paths = <_VectorPath>[];

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (binary[y][x] == 0 || visited[y][x] == 1) continue;

      final component = _collectComponent(binary, visited, width, height, x, y);
      if (component.length < _minAreaPx) continue;

      final boundary = _componentBoundary(component, binary, width, height);
      if (boundary.length < 2) continue;

      final orderedBoundary = _traceBoundary(boundary, width, height);
      if (orderedBoundary.length < 2) continue;

      var points = orderedBoundary
          .map((code) => _pixelToWorkspacePoint(code, width, height, workspaceWidthMm, workspaceHeightMm))
          .toList(growable: false);

      points = _removeRedundantPoints(points, minDistance: _minPointDistanceMm);
      if (points.length < 2) continue;

      points = _douglasPeucker(points, simplifyToleranceMm);
      points = _removeRedundantPoints(points, minDistance: _minPointDistanceMm);
      if (points.length < 2) continue;

      // Match the old Python/OpenCV output more closely:
      // OpenCV contours usually start at the first top-left boundary pixel found
      // during image scanning, then follow a consistent clockwise contour order
      // in image coordinates. Our pure-Dart tracer may discover the same contour
      // in the opposite direction, which still previews correctly but produces a
      // different G-code order. Normalizing the closed path here keeps the new
      // mobile output aligned with the old working G-code: same start region and
      // same direction, while preserving the user-defined Safe Area mapping.
      points = _normalizeClosedContourLikeOpenCv(points);

      final path = _VectorPath(points: points, closed: true)..calculateLength();
      if (path.lengthMm < _minPathLengthMm) continue;
      paths.add(path);
    }
  }

  // Same spirit as the Python version: largest/longest paths first before optimization.
  paths.sort((a, b) => b.lengthMm.compareTo(a.lengthMm));
  return paths;
}

List<int> _collectComponent(
  List<Uint8List> binary,
  List<Uint8List> visited,
  int width,
  int height,
  int startX,
  int startY,
) {
  final queue = <int>[_encode(startX, startY, width)];
  final component = <int>[];
  visited[startY][startX] = 1;

  var head = 0;
  while (head < queue.length) {
    final code = queue[head++];
    component.add(code);
    final x = code % width;
    final y = code ~/ width;

    for (final dir in _dirs8) {
      final nx = x + dir[0];
      final ny = y + dir[1];
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
      if (visited[ny][nx] == 1 || binary[ny][nx] == 0) continue;
      visited[ny][nx] = 1;
      queue.add(_encode(nx, ny, width));
    }
  }

  return component;
}

Set<int> _componentBoundary(List<int> component, List<Uint8List> binary, int width, int height) {
  final boundary = <int>{};

  for (final code in component) {
    final x = code % width;
    final y = code ~/ width;
    var isBoundary = false;

    const dirs4 = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];

    for (final dir in dirs4) {
      final nx = x + dir[0];
      final ny = y + dir[1];
      if (nx < 0 || nx >= width || ny < 0 || ny >= height || binary[ny][nx] == 0) {
        isBoundary = true;
        break;
      }
    }

    if (isBoundary) boundary.add(code);
  }

  return boundary;
}

List<int> _traceBoundary(Set<int> boundary, int width, int height) {
  if (boundary.length < 2) return boundary.toList(growable: false);

  final sorted = boundary.toList(growable: false)..sort();
  final start = sorted.first;
  var current = start;
  var backtrackX = (start % width) - 1;
  var backtrackY = start ~/ width;
  final startBacktrackX = backtrackX;
  final startBacktrackY = backtrackY;
  final contour = <int>[];
  final maxSteps = (boundary.length * 6) + 32;

  for (var step = 0; step < maxSteps; step++) {
    contour.add(current);

    final cx = current % width;
    final cy = current ~/ width;
    final backIndex = _directionIndex(backtrackX - cx, backtrackY - cy);
    final searchStart = backIndex < 0 ? 0 : (backIndex + 1) % 8;

    var found = false;
    var next = current;
    var nextBacktrackX = backtrackX;
    var nextBacktrackY = backtrackY;

    for (var offset = 0; offset < 8; offset++) {
      final dirIndex = (searchStart + offset) % 8;
      final nx = cx + _dirs8[dirIndex][0];
      final ny = cy + _dirs8[dirIndex][1];
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;

      final candidate = _encode(nx, ny, width);
      if (!boundary.contains(candidate)) continue;

      final previousIndex = (dirIndex + 7) % 8;
      next = candidate;
      nextBacktrackX = cx + _dirs8[previousIndex][0];
      nextBacktrackY = cy + _dirs8[previousIndex][1];
      found = true;
      break;
    }

    if (!found) break;

    current = next;
    backtrackX = nextBacktrackX;
    backtrackY = nextBacktrackY;

    if (current == start &&
        contour.length > 2 &&
        ((backtrackX == startBacktrackX && backtrackY == startBacktrackY) || contour.length > boundary.length)) {
      break;
    }
  }

  if (contour.length < math.min(12, boundary.length) || contour.length < boundary.length * 0.20) {
    return _greedyBoundaryOrder(boundary, width);
  }

  return contour;
}

List<int> _greedyBoundaryOrder(Set<int> boundary, int width) {
  final remaining = boundary.toSet();
  final ordered = <int>[];
  var current = (remaining.toList(growable: false)..sort()).first;
  ordered.add(current);
  remaining.remove(current);

  while (remaining.isNotEmpty && ordered.length < boundary.length) {
    final cx = current % width;
    final cy = current ~/ width;
    int? best;
    var bestDistance = double.infinity;

    for (final candidate in remaining) {
      final dx = (candidate % width) - cx;
      final dy = (candidate ~/ width) - cy;
      final d = (dx * dx) + (dy * dy).toDouble();
      if (d < bestDistance) {
        bestDistance = d;
        best = candidate;
      }
    }

    if (best == null) break;
    current = best;
    remaining.remove(current);
    ordered.add(current);
  }

  return ordered;
}

int _directionIndex(int dx, int dy) {
  final ndx = dx.clamp(-1, 1);
  final ndy = dy.clamp(-1, 1);
  for (var i = 0; i < _dirs8.length; i++) {
    if (_dirs8[i][0] == ndx && _dirs8[i][1] == ndy) return i;
  }
  return -1;
}

_Point _pixelToWorkspacePoint(
  int code,
  int width,
  int height,
  double workspaceWidthMm,
  double workspaceHeightMm,
) {
  final x = code % width;
  final y = code ~/ width;
  final xScale = workspaceWidthMm / math.max(1, width - 1);
  final yScale = workspaceHeightMm / math.max(1, height - 1);
  return _Point(x * xScale, y * yScale);
}

int _encode(int x, int y, int width) => (y * width) + x;

List<_Point> _removeRedundantPoints(List<_Point> points, {required double minDistance}) {
  if (points.isEmpty) return const [];
  final output = <_Point>[points.first];
  for (final point in points.skip(1)) {
    if (output.last.distanceTo(point) >= minDistance) {
      output.add(point);
    }
  }
  if (output.length > 2 && output.first.distanceTo(output.last) < minDistance) {
    output.removeLast();
  }
  return output;
}

List<_Point> _normalizeClosedContourLikeOpenCv(List<_Point> points) {
  if (points.length < 3) return points;

  var normalized = List<_Point>.from(points);

  // In the old Python/OpenCV pipeline the produced face contours had a
  // negative signed area in image/workspace coordinates (Y grows downward).
  // If the Dart tracer gives the opposite direction, reverse it. This turns
  // outputs like:
  //   top-left -> top-right -> right side -> bottom ...
  // back into the old style:
  //   top-left -> left side -> bottom -> right side ...
  if (_signedArea(normalized) > 0) {
    normalized = normalized.reversed.toList(growable: false);
  }

  final startIndex = _topLeftContourStartIndex(normalized);
  if (startIndex > 0) {
    normalized = _rotatePoints(normalized, startIndex);
  }

  return normalized;
}

double _signedArea(List<_Point> points) {
  if (points.length < 3) return 0;
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += (a.x * b.y) - (b.x * a.y);
  }
  return sum / 2.0;
}

int _topLeftContourStartIndex(List<_Point> points) {
  var best = 0;
  const yToleranceMm = 1.25;

  for (var i = 1; i < points.length; i++) {
    final candidate = points[i];
    final current = points[best];

    final clearlyHigher = candidate.y < current.y - yToleranceMm;
    final sameTopBand = (candidate.y - current.y).abs() <= yToleranceMm;
    if (clearlyHigher || (sameTopBand && candidate.x < current.x)) {
      best = i;
    }
  }

  return best;
}

List<_Point> _rotatePoints(List<_Point> points, int startIndex) {
  if (points.isEmpty || startIndex <= 0 || startIndex >= points.length) {
    return points;
  }
  return [
    ...points.sublist(startIndex),
    ...points.sublist(0, startIndex),
  ];
}

List<_Point> _douglasPeucker(List<_Point> points, double epsilon) {
  if (points.length < 3 || epsilon <= 0) return List<_Point>.from(points);

  var maxDistance = 0.0;
  var maxIndex = 0;

  for (var i = 1; i < points.length - 1; i++) {
    final distance = _pointLineDistance(points[i], points.first, points.last);
    if (distance > maxDistance) {
      maxDistance = distance;
      maxIndex = i;
    }
  }

  if (maxDistance > epsilon) {
    final left = _douglasPeucker(points.sublist(0, maxIndex + 1), epsilon);
    final right = _douglasPeucker(points.sublist(maxIndex), epsilon);
    return [...left.take(left.length - 1), ...right];
  }

  return [points.first, points.last];
}

double _pointLineDistance(_Point point, _Point start, _Point end) {
  final px = point.x;
  final py = point.y;
  final x1 = start.x;
  final y1 = start.y;
  final x2 = end.x;
  final y2 = end.y;
  final denom = math.sqrt(math.pow(y2 - y1, 2) + math.pow(x2 - x1, 2));
  if (denom == 0) return point.distanceTo(start);
  return ((y2 - y1) * px - (x2 - x1) * py + (x2 * y1) - (y2 * x1)).abs() / denom;
}

_FitTransform _fitToSafeArea(List<_VectorPath> paths, ImageGcodeSettings settings) {
  final xs = <double>[];
  final ys = <double>[];
  for (final path in paths) {
    for (final point in path.points) {
      xs.add(point.x);
      ys.add(point.y);
    }
  }

  if (xs.isEmpty || ys.isEmpty) {
    return const _FitTransform(scale: 1, offsetX: 0, offsetY: 0);
  }

  final minX = xs.reduce(math.min);
  final maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  final drawW = math.max(maxX - minX, 1e-6);
  final drawH = math.max(maxY - minY, 1e-6);

  // Same as Python _fit_transform, but instead of safe_margin it uses the
  // exact rectangle entered by the user.
  final safeScale = math.min(settings.safeWidthMm / drawW, settings.safeHeightMm / drawH);
  final offsetX = settings.safeXmm + ((settings.safeWidthMm - (drawW * safeScale)) / 2.0) - (minX * safeScale);
  final offsetY = settings.safeYmm + ((settings.safeHeightMm - (drawH * safeScale)) / 2.0) - (minY * safeScale);

  return _FitTransform(scale: safeScale, offsetX: offsetX, offsetY: offsetY);
}

List<_VectorPath> _transformPathsToSafeArea(
  List<_VectorPath> paths,
  ImageGcodeSettings settings,
  _FitTransform transform,
) {
  final minX = settings.safeXmm;
  final minY = settings.safeYmm;
  final maxX = settings.safeXmm + settings.safeWidthMm;
  final maxY = settings.safeYmm + settings.safeHeightMm;

  return paths.map((path) {
    final points = path.points.map((point) {
      final x = (point.x * transform.scale + transform.offsetX).clamp(minX, maxX).toDouble();
      final y = (point.y * transform.scale + transform.offsetY).clamp(minY, maxY).toDouble();
      return _Point(x, y);
    }).toList(growable: false);

    return _VectorPath(points: points, closed: path.closed)..calculateLength();
  }).toList(growable: false);
}

List<_VectorPath> _optimizePaths(List<_VectorPath> input, {required _Point startPoint}) {
  final paths = input
      .map((path) {
        final points = _removeRedundantPoints(path.points, minDistance: _minPointDistanceMm);
        return _VectorPath(points: points, closed: path.closed)..calculateLength();
      })
      .where((path) => path.points.length >= 2 && path.lengthMm >= _minPathLengthMm)
      .toList(growable: true);

  final ordered = <_VectorPath>[];
  var current = startPoint;

  while (paths.isNotEmpty) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    var reverseChosen = false;

    for (var i = 0; i < paths.length; i++) {
      final startDistance = current.distanceTo(paths[i].points.first);
      if (startDistance < bestDistance) {
        bestDistance = startDistance;
        bestIndex = i;
        reverseChosen = false;
      }

      // Match Python optimizer: only reverse open paths. Contours stay closed.
      if (!paths[i].closed) {
        final endDistance = current.distanceTo(paths[i].points.last);
        if (endDistance < bestDistance) {
          bestDistance = endDistance;
          bestIndex = i;
          reverseChosen = true;
        }
      }
    }

    final chosen = paths.removeAt(bestIndex);
    if (reverseChosen) {
      chosen.points = chosen.points.reversed.toList(growable: false);
      chosen.calculateLength();
    }
    ordered.add(chosen);
    current = chosen.points.last;
  }

  return ordered;
}

({String gcode, List<Map<String, dynamic>> segments, int commandCount, int segmentCount, double usedWidthMm, double usedHeightMm, bool truncated}) _generateGcode(
  List<_VectorPath> paths,
  ImageGcodeSettings settings,
) {
  final commands = <String>['M5'];
  final segments = <Map<String, dynamic>>[];
  var truncated = false;
  _Point? lastMove;

  bool canAddPath(_VectorPath path) {
    final estimated = path.points.length + 4 + (path.closed ? 1 : 0);
    return commands.length + estimated <= settings.maxCommands;
  }

  for (final path in paths) {
    if (path.points.length < 2) continue;
    if (!canAddPath(path)) {
      truncated = true;
      break;
    }

    final first = _roundedPoint(path.points.first);
    if (lastMove == null || !_sameRoundedPoint(lastMove, first)) {
      commands.add('G0 X${_fmt(first.x)} Y${_fmt(first.y)}');
    }
    commands.add('M3');

    var previous = first;
    for (final rawPoint in path.points.skip(1)) {
      final point = _roundedPoint(rawPoint);
      if (_sameRoundedPoint(previous, point)) continue;
      commands.add('G1 X${_fmt(point.x)} Y${_fmt(point.y)}');
      if (segments.length < _maxPreviewSegments) {
        segments.add({
          'startX': previous.x,
          'startY': previous.y,
          'endX': point.x,
          'endY': point.y,
        });
      }
      previous = point;
    }

    if (path.closed && !_sameRoundedPoint(previous, first)) {
      commands.add('G1 X${_fmt(first.x)} Y${_fmt(first.y)}');
      if (segments.length < _maxPreviewSegments) {
        segments.add({
          'startX': previous.x,
          'startY': previous.y,
          'endX': first.x,
          'endY': first.y,
        });
      }
      previous = first;
    }

    commands.add('M5');
    lastMove = previous;
  }

  if (commands.last != 'M5') commands.add('M5');

  final bounds = _segmentBounds(segments, settings);
  return (
    gcode: commands.join('\n'),
    segments: segments,
    commandCount: commands.where((line) => line.trim().isNotEmpty).length,
    segmentCount: segments.length,
    usedWidthMm: bounds.usedWidth,
    usedHeightMm: bounds.usedHeight,
    truncated: truncated,
  );
}

({double usedWidth, double usedHeight}) _segmentBounds(List<Map<String, dynamic>> segments, ImageGcodeSettings settings) {
  if (segments.isEmpty) return (usedWidth: 0, usedHeight: 0);

  final xs = <double>[];
  final ys = <double>[];
  for (final segment in segments) {
    xs
      ..add(segment['startX'] as double)
      ..add(segment['endX'] as double);
    ys
      ..add(segment['startY'] as double)
      ..add(segment['endY'] as double);
  }

  return (
    usedWidth: (xs.reduce(math.max) - xs.reduce(math.min)).clamp(0, settings.safeWidthMm).toDouble(),
    usedHeight: (ys.reduce(math.max) - ys.reduce(math.min)).clamp(0, settings.safeHeightMm).toDouble(),
  );
}

_Point _roundedPoint(_Point point) => _Point(double.parse(_fmt(point.x)), double.parse(_fmt(point.y)));

bool _sameRoundedPoint(_Point? a, _Point b) {
  if (a == null) return false;
  return (a.x - b.x).abs() < 0.005 && (a.y - b.y).abs() < 0.005;
}

String _fmt(double value) => value.toStringAsFixed(2);
