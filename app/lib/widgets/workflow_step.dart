import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WorkflowStepTile extends StatelessWidget {
  const WorkflowStepTile({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    this.done = false,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color =
        done ? AppTheme.success : (active ? AppTheme.primary : AppTheme.muted);

    // عرض ثابت يمنع مشاكل unbounded width داخل horizontal scroll/Wrap.
    // وجود Spacer داخل Widget عرضه غير محدد كان ممكن يعمل RenderBox بلا حجم
    // على بعض الأجهزة أثناء الـ hit testing.
    return SizedBox(
      width: 172,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.11)
              : AppTheme.elevated.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: color.withValues(alpha: active || done ? 0.42 : 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(done ? Icons.check_rounded : icon,
                      color: color, size: 19),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: color.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
