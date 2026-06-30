import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_constants.dart';
import '../models/generated_gcode.dart';
import '../models/robot_status.dart';
import '../services/esp_api_client.dart';
import '../services/image_to_gcode_converter.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/info_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/workflow_step.dart';
import '../widgets/gcode_path_preview.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_pill.dart';
import 'connection_screen.dart';
import 'gcode_editor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.espUrl});

  final String espUrl;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final EspApiClient _client;
  final _imagePicker = ImagePicker();
  final _safeXController = TextEditingController();
  final _safeYController = TextEditingController();
  final _safeWidthController = TextEditingController();
  final _safeHeightController = TextEditingController();
  final _previewScrollController = ScrollController();
  Timer? _pollTimer;
  Timer? _manualHoldTimer;
  Timer? _manualStatusTimer;

  RobotStatus _status = RobotStatus.empty();
  String _gcode = '';
  String _fileName = 'لا يوجد ملف';
  String _lastMessage = 'جاهز للاتصال بالروبوت';
  bool _isBusy = false;
  bool _manualInFlight = false;
  int? _queuedMoveAngle;
  bool _online = false;
  bool _isUploaded = false;
  int _pollFailures = 0;
  bool _shownGeneratedResetWarning = false;
  List<String> _gcodeLines = const [];

  Uint8List? _imageBytes;
  String _imageName = 'لا توجد صورة';
  GeneratedGcode? _generated;

  double _threshold = AppConstants.defaultThreshold.toDouble();
  double _rasterWidthPx = AppConstants.defaultRasterWidthPx.toDouble();
  double _rowStepPx = AppConstants.defaultRowStepPx.toDouble();
  double _safeXmm = AppConstants.defaultSafeXmm;
  double _safeYmm = AppConstants.defaultSafeYmm;
  double _safeWidthMm = AppConstants.defaultSafeWidthMm;
  double _safeHeightMm = AppConstants.defaultSafeHeightMm;
  bool _invertImage = true;
  bool _generatedFromImage = false;

  @override
  void initState() {
    super.initState();
    _syncSafeAreaControllers();
    _client = EspApiClient(widget.espUrl);
    _refreshStatus(showErrors: false);
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.statusPollSeconds),
      (_) => _refreshStatus(showErrors: false),
    );
  }

  void _restartStatusPolling() {
    _pollFailures = 0;
    _startStatusPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _manualHoldTimer?.cancel();
    _manualStatusTimer?.cancel();
    _safeXController.dispose();
    _safeYController.dispose();
    _safeWidthController.dispose();
    _safeHeightController.dispose();
    _previewScrollController.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus({bool showErrors = true}) async {
    // Do not fight the manual-control loop with extra HTTP requests. The
    // periodic poll will resume after the user releases the movement button.
    if (!showErrors && (_manualInFlight || _manualHoldTimer != null)) return;

    try {
      final status = await _client.getStatus();
      if (!mounted) return;

      final changed = !_online ||
          _status.state != status.state ||
          _status.pen != status.pen ||
          _status.current != status.current ||
          _status.total != status.total ||
          (_status.x - status.x).abs() > 0.05 ||
          (_status.y - status.y).abs() > 0.05 ||
          _status.stopRequested != status.stopRequested;

      if (!changed && !showErrors) return;

      setState(() {
        _status = status;
        _online = true;
        _pollFailures = 0;
        if (_pollTimer == null || !_pollTimer!.isActive) {
          _startStatusPolling();
        }
        if (showErrors) {
          _lastMessage =
              'آخر تحديث: ${DateTime.now().toLocal().toString().substring(11, 19)}';
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _pollFailures = showErrors ? 0 : _pollFailures + 1;
        if (!showErrors && _pollFailures >= 3) {
          _pollTimer?.cancel();
          _lastMessage = 'Offline - اضغط تحديث لإعادة المحاولة';
        } else {
          _lastMessage = 'الاتصال مقطوع';
        }
      });
      if (showErrors) {
        _restartStatusPolling();
        _showSnack('مشكلة اتصال: $e', error: true);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isBusy) return;
    HapticFeedback.selectionClick();

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('الصورة فاضية أو مش مقروءة', error: true);
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name.isEmpty ? 'صورة مختارة' : picked.name;
        _generated = null;
        if (_generatedFromImage) {
          _setGcodeState(
            '',
            fileName: 'اختار صورة جديدة - أعد التحويل',
            generatedFromImage: false,
          );
        }
      });
      _showSnack('تم اختيار الصورة. اضغط تحويل إلى G-code.', success: true);
    } on PlatformException catch (e) {
      _showSnack('مشكلة صلاحيات أو كاميرا: ${e.message ?? e.code}',
          error: true);
    } on Object catch (e) {
      _showSnack('فشل اختيار الصورة: $e', error: true);
    }
  }

  Future<void> _generateGcodeFromImage() async {
    final bytes = _imageBytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('اختار صورة من المعرض أو الكاميرا الأول', error: true);
      return;
    }

    if (_isBusy) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isBusy = true;
      _lastMessage = 'جاري تحويل الصورة إلى G-code...';
    });

    try {
      final validationMessage = _validateSafeArea();
      if (validationMessage != null) {
        _showSnack(validationMessage, error: true);
        if (mounted) setState(() => _isBusy = false);
        return;
      }

      final settings = ImageGcodeSettings(
        safeXmm: _safeXmm,
        safeYmm: _safeYmm,
        safeWidthMm: _safeWidthMm,
        safeHeightMm: _safeHeightMm,
        rasterWidthPx: _rasterWidthPx.round(),
        threshold: _threshold.round(),
        rowStepPx: _rowStepPx.round(),
        minRunPx: AppConstants.defaultMinRunPx,
        maxCommands: AppConstants.defaultMaxGeneratedCommands,
        invert: _invertImage,
      );

      final generated = await ImageToGcodeConverter.convert(
        imageBytes: bytes,
        settings: settings,
      );

      if (!mounted) return;
      setState(() {
        _setGcodeState(
          generated.gcode,
          fileName: 'Generated from $_imageName',
          generated: generated,
          generatedFromImage: true,
        );
        _lastMessage =
            generated.isEmpty ? 'الصورة لم تنتج خطوط رسم' : generated.summary;
      });

      if (generated.isEmpty) {
        _showSnack(
            'الصورة طلعت فاضية بعد التحويل. جرّب غيّر Threshold أو فعل Invert.',
            error: true);
      } else {
        _showSnack('تم توليد G-code من الصورة', success: true);
      }
    } on Object catch (e) {
      _showSnack('فشل تحويل الصورة: $e', error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _generateUploadRun() async {
    await _generateGcodeFromImage();
    if (!mounted || _gcode.trim().isEmpty) return;
    await _upload(runAfterUpload: true);
  }

  Future<void> _pickGcodeFile() async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gcode', 'nc', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('مش قادر أقرأ الملف. جرّب افتحه كنص من زر المحرر.',
          error: true);
      return;
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    setState(() {
      _setGcodeState(text, fileName: file.name, generatedFromImage: false);
    });
    _showSnack('تم تحميل الملف: ${file.name}', success: true);
  }

  Future<void> _openEditor() async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GcodeEditorScreen(initialText: _gcode),
      ),
    );

    if (edited == null) return;
    setState(() {
      _setGcodeState(edited,
          fileName: 'نص مكتوب يدويًا', generatedFromImage: false);
    });
    _showSnack('تم تحديث نص الـ G-code', success: true);
  }

  Future<void> _upload({required bool runAfterUpload}) async {
    if (_gcode.trim().isEmpty) {
      _showSnack('اختار صورة وحوّلها أو اختار ملف G-code الأول', error: true);
      return;
    }

    if (runAfterUpload) {
      final ok = await _confirmRun();
      if (!ok) return;
    }

    final success = await _runAction(
      loadingText:
          runAfterUpload ? 'جاري الرفع والتشغيل...' : 'جاري رفع G-code...',
      action: () async {
        final uploadMsg = await _client.uploadGcodeText(_gcode);
        if (runAfterUpload) {
          final runMsg = await _client.execute();
          return '$uploadMsg\n$runMsg';
        }
        return uploadMsg;
      },
    );
    if (success && mounted) {
      setState(() {
        _isUploaded = true;
      });
    }
  }

  Future<void> _executeOnly() async {
    final ok = await _confirmRun();
    if (!ok) return;
    await _runAction(
        loadingText: 'جاري تشغيل الرسم...', action: _client.execute);
  }

  Future<void> _stop() async {
    await _runAction(
        loadingText: 'جاري الإيقاف...', action: _client.stop, danger: true);
  }

  Future<void> _clear() async {
    final ok = await _confirm(
      title: 'مسح الأوامر؟',
      message: 'هيتم إيقاف التنفيذ ومسح قائمة الـ G-code من ESP.',
      actionText: 'مسح',
      danger: true,
    );
    if (!ok) return;
    await _runAction(
        loadingText: 'جاري المسح...', action: _client.clear, danger: true);
  }

  Future<void> _home() async {
    await _runAction(loadingText: 'جاري تصفير الموضع...', action: _client.home);
  }

  Future<void> _pen(bool down) async {
    await _runAction(
      loadingText: down ? 'جاري تنزيل القلم...' : 'جاري رفع القلم...',
      action: () => _client.setPen(down: down),
    );
  }

  Future<void> _move(int angle) async {
    if (_isBusy) return;
    HapticFeedback.selectionClick();

    // Keep only one HTTP move request in flight. If the user taps or holds
    // another direction while the ESP is still replying, keep the latest angle
    // only. This makes the UI feel smooth and prevents request flooding.
    if (_manualInFlight) {
      _queuedMoveAngle = angle;
      return;
    }

    await _sendManualMove(angle);
  }

  Future<void> _sendManualMove(int angle) async {
    _manualInFlight = true;
    // لا نعمل setState مع كل خطوة حركة، لأن ده كان بيعيد بناء الصفحة كلها
    // ويعمل تهنيج أثناء الضغط المطول. هنحدّث الرسالة داخليًا فقط، وحالة
    // الروبوت هتتحدث بعد انتهاء الحركة أو من الـ polling الهادئ.
    _lastMessage = 'Manual move: $angle°';

    try {
      await _client.move(angle: angle);
      _online = true;
    } on Object catch (e) {
      if (!mounted) return;
      _online = false;
      _lastMessage = 'فشل الحركة اليدوية';
      _showSnack(e.toString(), error: true);
    } finally {
      _manualInFlight = false;
      final nextAngle = _queuedMoveAngle;
      _queuedMoveAngle = null;

      if (nextAngle != null && mounted) {
        Future<void>.delayed(
          const Duration(milliseconds: 80),
          () {
            if (mounted) _sendManualMove(nextAngle);
          },
        );
      } else {
        if (mounted) setState(() {});
        _scheduleManualStatusRefresh();
      }
    }
  }

  void _startHoldingMove(int angle) {
    if (_isBusy) return;
    _manualHoldTimer?.cancel();
    _move(angle);
    _manualHoldTimer = Timer.periodic(
      const Duration(milliseconds: 220),
      (_) => _move(angle),
    );
  }

  void _stopHoldingMove() {
    _manualHoldTimer?.cancel();
    _manualHoldTimer = null;
    _scheduleManualStatusRefresh();
  }

  void _scheduleManualStatusRefresh() {
    _manualStatusTimer?.cancel();
    _manualStatusTimer = Timer(
      const Duration(milliseconds: 450),
      () => _refreshStatus(showErrors: false),
    );
  }

  Future<bool> _runAction({
    required String loadingText,
    required Future<String> Function() action,
    bool danger = false,
  }) async {
    if (_isBusy) return false;
    HapticFeedback.lightImpact();
    setState(() {
      _isBusy = true;
      _lastMessage = loadingText;
    });

    try {
      final message = await action();
      if (!mounted) return false;
      _showSnack(message.isEmpty ? 'تم بنجاح' : message, success: !danger);
      await _refreshStatus(showErrors: false);
      return true;
    } on Object catch (e) {
      _showSnack(e.toString(), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool> _confirmRun() {
    return _confirm(
      title: 'تأكيد التشغيل',
      message:
          'تأكد أن الورقة ثابتة، القلم مرفوع في البداية، وأن Safe Area الحالية صحيحة: ${_safeAreaSummary()}.',
      actionText: 'تشغيل',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionText,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? AppTheme.danger : AppTheme.primary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message, {bool error = false, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: error
            ? AppTheme.danger
            : (success ? AppTheme.success : AppTheme.primary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _disconnect() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectionScreen()),
    );
  }

  List<String> _splitGcodeLines(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  void _setGcodeState(
    String value, {
    required String fileName,
    GeneratedGcode? generated,
    required bool generatedFromImage,
  }) {
    _gcode = value;
    _gcodeLines = _splitGcodeLines(value);
    _fileName = fileName;
    _generated = generated;
    _generatedFromImage = generatedFromImage;
    _isUploaded = false;
    if (generatedFromImage) {
      _shownGeneratedResetWarning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.precision_manufacturing_rounded,
                  size: 21, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spidy Draw Control',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    widget.espUrl,
                    textDirection: TextDirection.ltr,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              _restartStatusPolling();
              _refreshStatus();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'تغيير ESP URL',
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          // شيلنا RefreshIndicator لأنه كان يدخل في hit-test/gesture conflicts
          // على بعض أجهزة Android أثناء السحب والضغط على الكروت. زر التحديث
          // موجود بالفعل في الـ AppBar.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth >= 1040 ? 1040.0 : double.infinity;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      _buildGraduationHero(),
                      const SizedBox(height: 14),
                      _buildHeroStatus(),
                      const SizedBox(height: 14),
                      _buildWorkflowCard(),
                      const SizedBox(height: 14),
                      _buildImageCard(),
                      const SizedBox(height: 14),
                      _buildGcodeCard(),
                      const SizedBox(height: 14),
                      _buildRunCard(),
                      const SizedBox(height: 14),
                      _buildManualCard(),
                      const SizedBox(height: 14),
                      _buildPreviewCard(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGraduationHero() {
    final readyToGenerate = _imageBytes != null;
    final readyToUpload = _gcode.trim().isNotEmpty;
    final totalLines = _gcodeLines.length;
    final stateColor = !_online
        ? AppTheme.danger
        : _status.isReady
            ? AppTheme.success
            : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.22)),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.primary, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Graduation Project Mode',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text(
                      'Image → Safe Area → G-code → ESP32',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: AppTheme.muted, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildResponsiveTiles(
            minTileWidth: 160,
            children: [
              InfoTile(
                label: 'Connection',
                value: _online ? 'ONLINE' : 'OFFLINE',
                icon: _online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: stateColor,
              ),
              InfoTile(
                label: 'Image',
                value: readyToGenerate ? 'SELECTED' : 'EMPTY',
                icon: readyToGenerate
                    ? Icons.image_rounded
                    : Icons.add_photo_alternate_rounded,
                color: readyToGenerate ? AppTheme.success : AppTheme.muted,
              ),
              InfoTile(
                label: 'G-code',
                value: readyToUpload ? '$totalLines lines' : 'NOT READY',
                icon: readyToUpload
                    ? Icons.code_rounded
                    : Icons.pending_actions_rounded,
                color: readyToUpload ? AppTheme.primary : AppTheme.muted,
              ),
              InfoTile(
                label: 'Safe Area',
                value:
                    '${_safeWidthMm.toStringAsFixed(0)}×${_safeHeightMm.toStringAsFixed(0)} mm',
                icon: Icons.crop_free_rounded,
                color: AppTheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard() {
    final hasImage = _imageBytes != null;
    final hasGenerated = _generated != null && _gcode.trim().isNotEmpty;
    final hasUploadedOrRunning = _isUploaded || _status.total > 0;

    return SectionCard(
      title: 'Demo Workflow',
      subtitle: 'الشكل اللي يتعرض قدام لجنة مشروع التخرج خطوة بخطوة',
      icon: Icons.route_rounded,
      accent: AppTheme.purple,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              WorkflowStepTile(
                number: 1,
                title: 'Connect',
                subtitle: 'ESP32 status confirmed',
                icon: Icons.wifi_tethering_rounded,
                active: _online && !hasImage,
                done: _online,
              ),
              const SizedBox(width: 10),
              WorkflowStepTile(
                number: 2,
                title: 'Image',
                subtitle: 'Camera or gallery input',
                icon: Icons.photo_camera_rounded,
                active: _online && !hasImage,
                done: hasImage,
              ),
              const SizedBox(width: 10),
              WorkflowStepTile(
                number: 3,
                title: 'Generate',
                subtitle: 'Local contours to G-code',
                icon: Icons.auto_fix_high_rounded,
                active: hasImage && !hasGenerated,
                done: hasGenerated,
              ),
              const SizedBox(width: 10),
              WorkflowStepTile(
                number: 4,
                title: 'Upload & Run',
                subtitle: 'Direct ESP execution',
                icon: Icons.rocket_launch_rounded,
                active: hasGenerated && !hasUploadedOrRunning,
                done: hasUploadedOrRunning,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatus() {
    final stateColor = !_online
        ? AppTheme.danger
        : _status.isReady
            ? AppTheme.success
            : AppTheme.secondary;
    final progressText = _status.total <= 0
        ? '0%'
        : '${(_status.progress * 100).toStringAsFixed(0)}%';

    return SectionCard(
      title: _online ? 'Live Robot Status' : 'Robot Offline',
      subtitle: _lastMessage,
      icon: _online ? Icons.sensors_rounded : Icons.wifi_off_rounded,
      accent: stateColor,
      trailing: _isBusy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: stateColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: stateColor, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text(
                    _online ? _status.state.toUpperCase() : 'OFFLINE',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        color: stateColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.elevated.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Drawing Progress',
                      style: TextStyle(
                          color: AppTheme.muted, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(progressText,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _status.progress,
                  minHeight: 11,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _lastMessage,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${_status.current}/${_status.total}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildResponsiveTiles(
          minTileWidth: 155,
          children: [
            StatusPill(
                label: 'الحالة',
                value: _status.state,
                icon: Icons.memory_rounded,
                color: stateColor),
            StatusPill(
                label: 'القلم',
                value: _status.pen,
                icon: Icons.edit_rounded,
                color:
                    _status.isPenDown ? AppTheme.secondary : AppTheme.primary),
            StatusPill(
                label: 'X',
                value: _status.x.toStringAsFixed(1),
                icon: Icons.swap_horiz_rounded),
            StatusPill(
                label: 'Y',
                value: _status.y.toStringAsFixed(1),
                icon: Icons.swap_vert_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCard() {
    final generated = _generated;
    final selectedImageBytes = _imageBytes;

    return SectionCard(
      title: 'Image to G-code Studio',
      subtitle:
          'اختار صورة، اضبط المنطقة الآمنة، وشوف المعاينة قبل تشغيل الجهاز',
      icon: Icons.image_search_rounded,
      accent: AppTheme.primary,
      children: [
        Container(
          height: 210,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: selectedImageBytes == null
              ? const _EmptyImageStage()
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.memory(selectedImageBytes,
                            fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.success, size: 16),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 190),
                              child: Text(
                                _imageName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PrimaryButton(
                label: 'اختيار صورة',
                icon: Icons.photo_library_rounded,
                outlined: true,
                onPressed: () => _pickImage(ImageSource.gallery)),
            PrimaryButton(
                label: 'كاميرا',
                icon: Icons.photo_camera_rounded,
                outlined: true,
                onPressed: () => _pickImage(ImageSource.camera)),
            PrimaryButton(
                label: 'تحويل فقط',
                icon: Icons.auto_fix_high_rounded,
                isBusy: _isBusy,
                onPressed: _generateGcodeFromImage),
            PrimaryButton(
                label: 'تحويل + رفع + تشغيل',
                icon: Icons.rocket_launch_rounded,
                isBusy: _isBusy,
                onPressed: _generateUploadRun),
          ],
        ),
        if (_isBusy && selectedImageBytes != null) ...[
          const SizedBox(height: 12),
          _buildProcessingBanner(),
        ],
        const SizedBox(height: 16),
        _buildConversionSettings(),
        const SizedBox(height: 16),
        GcodePathPreview(
          segments: generated?.segments ?? const [],
          emptyText: 'بعد التحويل هتظهر معاينة مسار الرسم هنا داخل Safe Area',
          safeXmm: generated?.safeXmm,
          safeYmm: generated?.safeYmm,
          safeWidthMm: generated?.safeWidthMm,
          safeHeightMm: generated?.safeHeightMm,
        ),
        if (generated != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: generated.truncated
                  ? AppTheme.secondary.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: generated.truncated
                      ? AppTheme.secondary.withValues(alpha: 0.3)
                      : AppTheme.success.withValues(alpha: 0.22)),
            ),
            child: Text(
              generated.summary,
              style: TextStyle(
                color:
                    generated.truncated ? AppTheme.secondary : AppTheme.success,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'أفضل نتيجة: استخدم Logo أو Line art أبيض وأسود. لو التفاصيل كتير، قلل تفاصيل الصورة أو زوّد تبسيط المسار عشان عدد أوامر الـ ESP يقل.',
          style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildProcessingBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.24)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'جاري تحليل الصورة واستخراج الـ Contours...',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(minHeight: 6),
        ],
      ),
    );
  }

  void _updateConversionSetting(VoidCallback updater) {
    final hadGeneratedGcode = _generatedFromImage && _gcode.trim().isNotEmpty;
    setState(() {
      updater();
      _generated = null;
      if (hadGeneratedGcode) {
        _setGcodeState(
          '',
          fileName: 'تم تغيير إعدادات التحويل - أعد توليد G-code',
          generatedFromImage: false,
        );
      }
    });

    if (hadGeneratedGcode && !_shownGeneratedResetWarning) {
      _shownGeneratedResetWarning = true;
      _showSnack(
          'تم مسح الـ G-code القديم بعد تغيير الإعدادات. أعد التحويل قبل الرفع.');
    }
  }

  void _syncSafeAreaControllers() {
    _safeXController.text = _safeXmm.toStringAsFixed(0);
    _safeYController.text = _safeYmm.toStringAsFixed(0);
    _safeWidthController.text = _safeWidthMm.toStringAsFixed(0);
    _safeHeightController.text = _safeHeightMm.toStringAsFixed(0);
  }

  void _setSafeAreaValues({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    _safeXmm = x;
    _safeYmm = y;
    _safeWidthMm = width;
    _safeHeightMm = height;
    _syncSafeAreaControllers();
  }

  void _applyDefaultSafeArea() {
    _updateConversionSetting(() {
      _setSafeAreaValues(
        x: AppConstants.defaultSafeXmm,
        y: AppConstants.defaultSafeYmm,
        width: AppConstants.defaultSafeWidthMm,
        height: AppConstants.defaultSafeHeightMm,
      );
    });
  }

  void _applyA4PortraitSafeArea() {
    // Same safe area used by the firmware config: A4 210x297 with 20mm margins.
    _updateConversionSetting(() {
      _setSafeAreaValues(x: 20, y: 20, width: 170, height: 257);
    });
  }

  void _applyA4LandscapeSafeArea() {
    // Landscape-like rectangle that still stays inside the firmware A4 coordinate system.
    _updateConversionSetting(() {
      _setSafeAreaValues(x: 20, y: 88, width: 170, height: 120);
    });
  }

  String _safeAreaSummary() {
    return 'X=${_safeXmm.toStringAsFixed(1)}, Y=${_safeYmm.toStringAsFixed(1)}, W=${_safeWidthMm.toStringAsFixed(1)}, H=${_safeHeightMm.toStringAsFixed(1)} mm';
  }

  String? _validateSafeArea() {
    if (_safeXmm < 0 || _safeYmm < 0) {
      return 'X و Y في Safe Area لازم يكونوا صفر أو أكبر.';
    }
    if (_safeWidthMm < 10 || _safeHeightMm < 10) {
      return 'Safe Area صغيرة جدًا. خلي العرض والارتفاع أكبر من 10 mm.';
    }
    if (_safeXmm + _safeWidthMm > 210 || _safeYmm + _safeHeightMm > 297) {
      return 'Safe Area لازم تكون داخل A4: X ≤ 210mm و Y ≤ 297mm.';
    }
    return null;
  }

  Widget _buildConversionSettings() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('إعدادات التحويل',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              FilterChip(
                label: const Text('Black strokes'),
                selected: _invertImage,
                onSelected: _isBusy
                    ? null
                    : (value) =>
                        _updateConversionSetting(() => _invertImage = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSafeAreaEditor(),
          const SizedBox(height: 12),
          _sliderTile(
            label: 'Threshold',
            value: _threshold,
            min: 40,
            max: 230,
            divisions: 190,
            display: _threshold.round().toString(),
            onChanged: (v) => _updateConversionSetting(() => _threshold = v),
          ),
          _sliderTile(
            label: 'تفاصيل الصورة',
            value: _rasterWidthPx,
            min: 80,
            max: 320,
            divisions: 24,
            display: '${_rasterWidthPx.round()} px',
            onChanged: (v) =>
                _updateConversionSetting(() => _rasterWidthPx = v),
          ),
          _sliderTile(
            label: 'تبسيط المسار',
            value: _rowStepPx,
            min: 1,
            max: 6,
            divisions: 5,
            display: '${(_rowStepPx * 0.4).toStringAsFixed(1)} mm',
            onChanged: (v) => _updateConversionSetting(() => _rowStepPx = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeAreaEditor() {
    final validation = _validateSafeArea();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: validation == null ? AppTheme.border : AppTheme.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.crop_free_rounded,
                  color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Safe Drawing Area',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text(
                'mm',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    color:
                        validation == null ? AppTheme.muted : AppTheme.danger,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'دي حدود المنطقة اللي الرسم مسموح يدخلها. التطبيق هيكبر/يصغر الصورة ويحطها في النص جوه الحدود دي فقط.',
            style: TextStyle(
                color: validation == null ? AppTheme.muted : AppTheme.danger,
                fontSize: 12,
                height: 1.45),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          label: 'Start X',
                          controller: _safeXController,
                          minValue: 0,
                          maxValue: 210,
                          onChanged: (v) =>
                              _updateConversionSetting(() => _safeXmm = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numberField(
                          label: 'Start Y',
                          controller: _safeYController,
                          minValue: 0,
                          maxValue: 297,
                          onChanged: (v) =>
                              _updateConversionSetting(() => _safeYmm = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          label: 'Safe Width',
                          controller: _safeWidthController,
                          minValue: 10,
                          maxValue: 210,
                          onChanged: (v) =>
                              _updateConversionSetting(() => _safeWidthMm = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numberField(
                          label: 'Safe Height',
                          controller: _safeHeightController,
                          minValue: 10,
                          maxValue: 297,
                          onChanged: (v) =>
                              _updateConversionSetting(() => _safeHeightMm = v),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final preview = _A4SafeAreaMiniPreview(
                safeX: _safeXmm,
                safeY: _safeYmm,
                safeW: _safeWidthMm,
                safeH: _safeHeightMm,
                valid: validation == null,
              );

              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields),
                    const SizedBox(width: 14),
                    preview,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fields,
                  const SizedBox(height: 12),
                  Center(child: preview),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Default'),
                onPressed: _isBusy ? null : _applyDefaultSafeArea,
              ),
              ActionChip(
                avatar:
                    const Icon(Icons.stay_current_portrait_rounded, size: 18),
                label: const Text('A4 Portrait'),
                onPressed: _isBusy ? null : _applyA4PortraitSafeArea,
              ),
              ActionChip(
                avatar:
                    const Icon(Icons.stay_current_landscape_rounded, size: 18),
                label: const Text('Wide Area'),
                onPressed: _isBusy ? null : _applyA4LandscapeSafeArea,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            validation ?? 'Current: ${_safeAreaSummary()}',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: validation == null ? AppTheme.muted : AppTheme.danger,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style:
                        const TextStyle(color: AppTheme.muted, fontSize: 12))),
            Text(display,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: _isBusy ? null : onChanged,
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required double minValue,
    required double maxValue,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isBusy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mm',
      ),
      onChanged: (text) {
        final parsed = double.tryParse(text.trim());
        if (parsed == null) return;
        final clamped = parsed.clamp(minValue, maxValue).toDouble();
        if (clamped != parsed) {
          final newText = clamped
              .toStringAsFixed(clamped.truncateToDouble() == clamped ? 0 : 1);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
        onChanged(clamped);
      },
    );
  }

  Widget _buildGcodeCard() {
    final lines = _gcodeLines.length;
    return SectionCard(
      title: 'G-code Source',
      subtitle:
          'Generated أو ملف جاهز أو نص يدوي — كله بيتنضف قبل الرفع للـ ESP',
      icon: Icons.file_upload_rounded,
      accent: AppTheme.success,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.elevated.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.description_rounded,
                    color: AppTheme.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('$lines سطر جاهز للرفع',
                        style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: lines > 0
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.elevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: lines > 0
                              ? AppTheme.success.withValues(alpha: 0.25)
                              : AppTheme.softBorder),
                    ),
                    child: Text(
                      lines > 0 ? 'READY' : 'EMPTY',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: lines > 0 ? AppTheme.success : AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (_isUploaded) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done_rounded,
                              size: 14, color: AppTheme.success),
                          SizedBox(width: 5),
                          Text('UPLOADED',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PrimaryButton(
                label: 'اختيار ملف',
                icon: Icons.folder_open_rounded,
                outlined: true,
                onPressed: _pickGcodeFile),
            PrimaryButton(
                label: 'كتابة / تعديل',
                icon: Icons.edit_note_rounded,
                outlined: true,
                onPressed: _openEditor),
            PrimaryButton(
                label: 'رفع فقط',
                icon: Icons.cloud_upload_rounded,
                isBusy: _isBusy,
                onPressed: () => _upload(runAfterUpload: false)),
            PrimaryButton(
                label: 'رفع وتشغيل',
                icon: Icons.play_arrow_rounded,
                isBusy: _isBusy,
                onPressed: () => _upload(runAfterUpload: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildRunCard() {
    return SectionCard(
      title: 'Execution Controls',
      subtitle: 'أوامر تشغيل آمنة قبل تحريك الموتورات',
      icon: Icons.play_circle_rounded,
      accent: AppTheme.secondary,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PrimaryButton(
                label: 'تشغيل الموجود',
                icon: Icons.play_arrow_rounded,
                isBusy: _isBusy,
                onPressed: _executeOnly),
            PrimaryButton(
                label: 'إيقاف فوري',
                icon: Icons.stop_rounded,
                isDanger: true,
                isBusy: _isBusy,
                onPressed: _stop),
            PrimaryButton(
                label: 'مسح Queue',
                icon: Icons.delete_sweep_rounded,
                isDanger: true,
                outlined: true,
                isBusy: _isBusy,
                onPressed: _clear),
            PrimaryButton(
                label: 'تصفير الموضع',
                icon: Icons.home_rounded,
                outlined: true,
                isBusy: _isBusy,
                onPressed: _home),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppTheme.secondary.withValues(alpha: 0.22)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppTheme.secondary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'قبل التشغيل: ثبت الورقة، ارفع القلم، واتأكد إن Safe Area مطابقة للمساحة الحقيقية على الجهاز.',
                  style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualCard() {
    return SectionCard(
      title: 'Manual Calibration Pad',
      subtitle:
          'اضغط ضغطة واحدة للحركة خطوة، أو اضغط مطولًا لحركة مستمرة بسلاسة',
      icon: Icons.gamepad_rounded,
      accent: AppTheme.primary,
      children: [
        Row(
          children: [
            Expanded(
                child: PrimaryButton(
                    label: 'القلم فوق',
                    icon: Icons.keyboard_arrow_up_rounded,
                    outlined: true,
                    onPressed: () => _pen(false))),
            const SizedBox(width: 10),
            Expanded(
                child: PrimaryButton(
                    label: 'القلم تحت',
                    icon: Icons.keyboard_arrow_down_rounded,
                    outlined: true,
                    onPressed: () => _pen(true))),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 270,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Column(
              children: [
                _movePadButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    label: 'Y+',
                    moveAngle: 90),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _movePadButton(
                        icon: Icons.keyboard_arrow_right_rounded,
                        label: 'X-',
                        moveAngle: 180),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundMoveButton(
                            icon: Icons.my_location_rounded,
                            onPressed: _home,
                            color: AppTheme.secondary),
                        const SizedBox(height: 5),
                        const Text('HOME',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                    _movePadButton(
                        icon: Icons.keyboard_arrow_left_rounded,
                        label: 'X+',
                        moveAngle: 0),
                  ],
                ),
                const SizedBox(height: 10),
                _movePadButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    label: 'Y-',
                    moveAngle: 270),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'اضغط مطولًا للحركة المستمرة. الليبل X+/Y+ يوضح اتجاه الحركة حسب firmware الحالي.',
          style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _movePadButton({
    required IconData icon,
    required String label,
    required int moveAngle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundMoveButton(icon: icon, moveAngle: moveAngle),
        const SizedBox(height: 5),
        Text(
          label,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _roundMoveButton({
    required IconData icon,
    VoidCallback? onPressed,
    int? moveAngle,
    Color color = AppTheme.primary,
  }) {
    final disabled = _isBusy || (onPressed == null && moveAngle == null);
    final backgroundAlpha = disabled ? 0.05 : 0.12;
    final borderAlpha = disabled ? 0.14 : 0.3;
    final iconColor = disabled ? AppTheme.muted : color;

    void triggerTap() {
      if (disabled) return;
      if (moveAngle != null) {
        _move(moveAngle);
      } else {
        onPressed?.call();
      }
    }

    return SizedBox(
      width: 58,
      height: 58,
      child: GestureDetector(
        onTap: triggerTap,
        onLongPressStart: moveAngle == null || disabled
            ? null
            : (_) => _startHoldingMove(moveAngle!),
        onLongPressEnd:
            moveAngle == null || disabled ? null : (_) => _stopHoldingMove(),
        onLongPressCancel:
            moveAngle == null || disabled ? null : _stopHoldingMove,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: color.withValues(alpha: backgroundAlpha),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: borderAlpha)),
            boxShadow: disabled
                ? const []
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
      ),
    );
  }

  Widget _buildResponsiveTiles({
    required List<Widget> children,
    double minTileWidth = 160,
    double spacing = 10,
    double runSpacing = 10,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final safeWidth = maxWidth <= 0 ? minTileWidth : maxWidth;
        final columnCount =
            (safeWidth / minTileWidth).floor().clamp(1, children.length);
        final tileWidth =
            (safeWidth - (spacing * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: tileWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewCard() {
    final totalLines = _gcodeLines.length;
    final previewLines =
        _gcodeLines.take(AppConstants.maxPreviewLines).join('\n');
    return SectionCard(
      title: 'G-code Console Preview',
      subtitle: 'معاينة أول أوامر قبل الرفع — مفيدة في العرض والتصحيح',
      icon: Icons.terminal_rounded,
      accent: AppTheme.success,
      trailing: Text(
        '$totalLines lines',
        textDirection: TextDirection.ltr,
        style:
            const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w900),
      ),
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 170, maxHeight: 360),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.18)),
          ),
          child: Scrollbar(
            controller: _previewScrollController,
            thumbVisibility: totalLines > 18,
            child: SingleChildScrollView(
              controller: _previewScrollController,
              child: Text(
                previewLines.isEmpty ? 'لا يوجد G-code للمعاينة' : previewLines,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Color(0xFFBFF7D3),
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (totalLines > AppConstants.maxPreviewLines) ...[
          const SizedBox(height: 8),
          Text(
            'المعاينة بتعرض أول ${AppConstants.maxPreviewLines} سطر فقط من أصل $totalLines.',
            style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

class _A4SafeAreaMiniPreview extends StatelessWidget {
  const _A4SafeAreaMiniPreview({
    required this.safeX,
    required this.safeY,
    required this.safeW,
    required this.safeH,
    required this.valid,
  });

  final double safeX;
  final double safeY;
  final double safeW;
  final double safeH;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final color = valid ? AppTheme.secondary : AppTheme.danger;
    return Container(
      width: 118,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 78,
            height: 110,
            child: CustomPaint(
              painter: _A4SafeAreaPainter(
                safeX: safeX,
                safeY: safeY,
                safeW: safeW,
                safeH: safeH,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valid ? 'A4 Safe' : 'Out of A4',
            textDirection: TextDirection.ltr,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _A4SafeAreaPainter extends CustomPainter {
  const _A4SafeAreaPainter({
    required this.safeX,
    required this.safeY,
    required this.safeW,
    required this.safeH,
    required this.color,
  });

  final double safeX;
  final double safeY;
  final double safeW;
  final double safeH;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paperPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final paperBorder = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final safePaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final safeBorder = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paperAspect = 210.0 / 297.0;
    final h = size.height;
    final w = h * paperAspect;
    final left = (size.width - w) / 2;
    final paper = Rect.fromLTWH(left, 0, w, h);
    canvas.drawRRect(
        RRect.fromRectAndRadius(paper, const Radius.circular(4)), paperPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(paper, const Radius.circular(4)), paperBorder);

    final safe = Rect.fromLTWH(
      paper.left + (safeX / 210.0) * paper.width,
      paper.top + (safeY / 297.0) * paper.height,
      (safeW / 210.0) * paper.width,
      (safeH / 297.0) * paper.height,
    );
    canvas.drawRect(safe, safePaint);
    canvas.drawRect(safe, safeBorder);
  }

  @override
  bool shouldRepaint(covariant _A4SafeAreaPainter oldDelegate) {
    return oldDelegate.safeX != safeX ||
        oldDelegate.safeY != safeY ||
        oldDelegate.safeW != safeW ||
        oldDelegate.safeH != safeH ||
        oldDelegate.color != color;
  }
}

class _EmptyImageStage extends StatelessWidget {
  const _EmptyImageStage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(26),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
            ),
            child: const Icon(Icons.add_photo_alternate_rounded,
                color: AppTheme.primary, size: 36),
          ),
          const SizedBox(height: 14),
          const Text('اختار صورة أو صوّر بالكاميرا',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'بعدها التطبيق هيحول الصورة إلى G-code محليًا',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
