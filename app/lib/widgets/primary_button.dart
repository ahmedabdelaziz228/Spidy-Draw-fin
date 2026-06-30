import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.isDanger = false,
    this.outlined = false,
    this.fullWidth = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final bool isDanger;
  final bool outlined;
  final bool fullWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppTheme.danger : AppTheme.primary;
    final effectiveOnPressed = isBusy ? null : onPressed;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: isBusy
          ? const SizedBox(
              key: ValueKey('loader'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
    );

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 15);

    final button = outlined
        ? OutlinedButton(
            onPressed: effectiveOnPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.62)),
              padding: padding,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              backgroundColor: color.withValues(alpha: 0.05),
              disabledForegroundColor: AppTheme.muted.withValues(alpha: 0.55),
            ),
            child: child,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient:
                  isDanger ? AppTheme.dangerGradient : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: effectiveOnPressed == null
                  ? const []
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.23),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: FilledButton(
              onPressed: effectiveOnPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor:
                    AppTheme.elevated.withValues(alpha: 0.72),
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: padding,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: child,
            ),
          );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
