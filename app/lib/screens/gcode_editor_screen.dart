import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class GcodeEditorScreen extends StatefulWidget {
  const GcodeEditorScreen({super.key, required this.initialText});

  final String initialText;

  @override
  State<GcodeEditorScreen> createState() => _GcodeEditorScreenState();
}

class _GcodeEditorScreenState extends State<GcodeEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محرر G-code'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            icon: const Icon(Icons.check_rounded),
            label: const Text('حفظ'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'اكتب أو الصق G-code هنا. التطبيق هيرسل للـ ESP الأوامر المدعومة فقط: G0/G1/M3/M5/G21/G90.',
              style: TextStyle(color: AppTheme.muted, height: 1.5),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5),
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'G-code',
                  hintText: 'G21\nG90\nM5\nG0 X10 Y10\nM3\nG1 X80 Y10\nM5',
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'إلغاء',
                    outlined: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'حفظ النص',
                    icon: Icons.save_rounded,
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
