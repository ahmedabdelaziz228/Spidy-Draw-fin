import 'dart:convert';

class RobotStatus {
  final String state;
  final String pen;
  final double x;
  final double y;
  final int current;
  final int total;
  final bool stopRequested;

  const RobotStatus({
    required this.state,
    required this.pen,
    required this.x,
    required this.y,
    required this.current,
    required this.total,
    required this.stopRequested,
  });

  factory RobotStatus.empty() {
    return const RobotStatus(
      state: 'unknown',
      pen: 'up',
      x: 0,
      y: 0,
      current: 0,
      total: 0,
      stopRequested: false,
    );
  }

  factory RobotStatus.fromJson(Map<String, dynamic> json) {
    return RobotStatus(
      state: json['state']?.toString() ?? 'unknown',
      pen: json['pen']?.toString() ?? 'up',
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      current: _toInt(json['current']),
      total: _toInt(json['total']),
      stopRequested: json['stopRequested'] == true ||
          json['stopRequested']?.toString().toLowerCase() == 'true',
    );
  }

  factory RobotStatus.fromBody(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return RobotStatus.fromJson(decoded);
  }

  double get progress {
    if (total <= 0) return 0;
    final value = current / total;
    return value.clamp(0, 1).toDouble();
  }

  bool get isReady => state.toLowerCase() == 'ready';
  bool get isBusy =>
      state.toLowerCase() == 'executing' || state.toLowerCase() == 'moving';
  bool get isPenDown => pen.toLowerCase() == 'down';

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
