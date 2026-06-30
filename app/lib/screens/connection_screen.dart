import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_constants.dart';
import '../core/url_normalizer.dart';
import '../services/esp_api_client.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/primary_button.dart';
import 'dashboard_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _controller = TextEditingController(text: AppConstants.defaultEspUrl);
  final _settings = const SettingsService();
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final saved = await _settings.loadEspUrl();
    if (!mounted) return;
    _controller.text = saved;
  }

  Future<void> _connect() async {
    final normalized = UrlNormalizer.normalize(_controller.text);
    if (!UrlNormalizer.isProbablyValid(normalized)) {
      _showSnack('اكتب عنوان ESP صحيح، مثال: http://192.168.4.1', error: true);
      return;
    }

    setState(() => _isBusy = true);
    HapticFeedback.lightImpact();

    final client = EspApiClient(normalized);
    try {
      await client.getStatus();
      await _settings.saveEspUrl(normalized);
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(espUrl: normalized),
        ),
      );
    } on Object catch (e) {
      _showSnack('مش قادر أوصل للـ ESP: $e', error: true);
    } finally {
      client.dispose();
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _useUrl(String url) {
    HapticFeedback.selectionClick();
    _controller.text = url;
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.danger : AppTheme.success,
        action: error
            ? SnackBarAction(
                label: 'إعادة المحاولة',
                textColor: Colors.white,
                onPressed: _connect,
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(child: _BrandPanel()),
                              const SizedBox(width: 22),
                              Expanded(child: _buildConnectPanel()),
                            ],
                          )
                        : Column(
                            children: [
                              const _BrandPanel(compact: true),
                              const SizedBox(height: 18),
                              _buildConnectPanel(),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConnectPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connect to Robot',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('ESP32 direct mode',
                          style: TextStyle(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'ESP32 URL',
                hintText: AppConstants.defaultEspUrl,
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  tooltip: 'مسح',
                  onPressed: _isBusy ? null : _controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickUrlChip(
                    label: 'Default AP',
                    url: AppConstants.defaultEspUrl,
                    onTap: _useUrl),
                _QuickUrlChip(
                    label: 'Router 192.168.1.x',
                    url: 'http://192.168.1.100',
                    onTap: _useUrl),
                _QuickUrlChip(
                    label: 'Router 192.168.0.x',
                    url: 'http://192.168.0.100',
                    onTap: _useUrl),
              ],
            ),
            const SizedBox(height: 18),
            const _ConnectionHint(
              icon: Icons.wifi_rounded,
              title: 'وصل الموبايل على Wi‑Fi بتاع الروبوت',
              text:
                  'لو شغال Access Point استخدم غالبًا 192.168.4.1، ولو شغال على راوتر استخدم IP الظاهر في Serial Monitor.',
            ),
            const SizedBox(height: 10),
            const _ConnectionHint(
              icon: Icons.security_rounded,
              title: 'التطبيق يتأكد من /status قبل الدخول',
              text: 'ده يمنع إنك تدخل على Dashboard والروبوت مش متوصل فعليًا.',
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'اختبار الاتصال والدخول',
              icon: Icons.login_rounded,
              isBusy: _isBusy,
              fullWidth: true,
              onPressed: _connect,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 22 : 30),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 78 : 96,
            height: compact ? 78 : 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Icon(
              Icons.precision_manufacturing_rounded,
              color: Colors.white,
              size: compact ? 42 : 52,
            ),
          ),
          SizedBox(height: compact ? 18 : 26),
          Text(
            'Spidy Draw\nGraduation Controller',
            style: TextStyle(
              fontSize: compact ? 30 : 40,
              fontWeight: FontWeight.w900,
              height: 1.04,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mobile app for image capture, local G-code generation, safe-area calibration, and direct ESP32 control.',
            style: TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeatureBadge(
                  icon: Icons.photo_camera_rounded, label: 'Image input'),
              _FeatureBadge(icon: Icons.code_rounded, label: 'Local G-code'),
              _FeatureBadge(icon: Icons.crop_free_rounded, label: 'Safe Area'),
              _FeatureBadge(icon: Icons.memory_rounded, label: 'ESP32'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 17),
          const SizedBox(width: 7),
          Text(label,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _QuickUrlChip extends StatelessWidget {
  const _QuickUrlChip(
      {required this.label, required this.url, required this.onTap});

  final String label;
  final String url;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.bolt_rounded, size: 18),
      label: Text(label),
      onPressed: () => onTap(url),
    );
  }
}

class _ConnectionHint extends StatelessWidget {
  const _ConnectionHint(
      {required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
