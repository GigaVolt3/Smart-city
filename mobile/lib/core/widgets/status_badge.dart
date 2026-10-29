import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays a complaint status badge with appropriate color coding.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    final bg = AppTheme.statusBgColor(status);
    final label = AppTheme.statusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppTheme.sp8 : AppTheme.sp12,
        vertical: compact ? 3 : AppTheme.sp4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Severity chip.
class SeverityBadge extends StatelessWidget {
  final String severity;

  const SeverityBadge({super.key, required this.severity});

  Color get _color => switch (severity.toLowerCase()) {
        'critical' => AppTheme.errorRed,
        'high' => AppTheme.warningAmber,
        'medium' => AppTheme.infoBlue,
        'low' => AppTheme.successGreen,
        _ => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
