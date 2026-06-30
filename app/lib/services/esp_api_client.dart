import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../core/url_normalizer.dart';
import '../models/robot_status.dart';

class EspApiException implements Exception {
  final String message;

  const EspApiException(this.message);

  @override
  String toString() => message;
}

class EspApiClient {
  EspApiClient(String espUrl) : baseUrl = UrlNormalizer.normalize(espUrl);

  final String baseUrl;
  final http.Client _client = http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return base.resolve(normalizedPath).replace(queryParameters: query);
  }

  Future<RobotStatus> getStatus() async {
    final response = await _client
        .get(_uri('/status'))
        .timeout(const Duration(seconds: AppConstants.shortTimeoutSeconds));
    _ensureOk(response, 'فشل قراءة حالة الروبوت');
    return RobotStatus.fromBody(response.body);
  }

  Future<String> uploadGcodeText(String gcode) async {
    final clean = _cleanGcode(gcode);
    if (clean.trim().isEmpty) {
      throw const EspApiException('ملف الـ G-code فاضي أو مفيهوش أوامر مفهومة');
    }

    final response = await _client
        .post(
          _uri('/upload-text'),
          headers: const {
            'Content-Type': 'text/plain; charset=utf-8',
          },
          body: clean,
          encoding: utf8,
        )
        .timeout(const Duration(seconds: AppConstants.longTimeoutSeconds));
    _ensureOk(response, 'فشل رفع الـ G-code للـ ESP');
    return response.body.trim();
  }

  Future<String> execute() => _getPlain('/execute', 'فشل تشغيل الرسم');
  Future<String> stop() => _getPlain('/stop', 'فشل إيقاف الروبوت');
  Future<String> clear() => _getPlain('/clear', 'فشل مسح قائمة الأوامر');
  Future<String> home() => _getPlain('/home', 'فشل تصفير مكان الروبوت');

  Future<String> setPen({required bool down}) {
    return _getPlain('/servo', 'فشل تحريك القلم', {'pos': down ? '1' : '0'});
  }

  Future<String> move({required int angle, int repeats = 1}) {
    return _getPlain(
      '/move',
      'فشل تحريك الروبوت يدويًا',
      {
        'angle': angle.toString(),
        'repeats': repeats.clamp(1, 20).toString(),
      },
      AppConstants.manualTimeoutSeconds,
    );
  }

  Future<String> _getPlain(
    String path,
    String fallbackMessage, [
    Map<String, String>? query,
    int timeoutSeconds = AppConstants.shortTimeoutSeconds,
  ]) async {
    final response = await _client
        .get(_uri(path, query))
        .timeout(Duration(seconds: timeoutSeconds));
    _ensureOk(response, fallbackMessage);
    return response.body.trim();
  }

  void _ensureOk(http.Response response, String fallbackMessage) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final body = response.body.trim();
    throw EspApiException(body.isEmpty ? fallbackMessage : body);
  }

  String _cleanGcode(String input) {
    final allowedPrefixes = <String>{
      'G0',
      'G00',
      'G1',
      'G01',
      'G21',
      'G90',
      'M3',
      'M5'
    };
    final lines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) {
          final withoutComment = line.split(';').first.trim();
          if (withoutComment.isEmpty) return '';
          final prefix =
              withoutComment.split(RegExp(r'\s+')).first.toUpperCase();
          if (!allowedPrefixes.contains(prefix)) return '';
          return withoutComment;
        })
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return lines.join('\n');
  }

  void dispose() => _client.close();
}
