import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CivicCard extends StatelessWidget {
  const CivicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: content,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    final trailing = action;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitleText != null) ...[
                const SizedBox(height: 2),
                Text(subtitleText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.compact = false});

  final String status;
  final bool compact;

  static const _labels = {
    'submitted': 'Submitted',
    'assigned': 'Assigned',
    'in_progress': 'In progress',
    'escalated': 'Escalated',
    'resolved': 'Resolved',
    'rejected': 'Rejected',
  };

  static const _colors = {
    'submitted': AppColors.info,
    'assigned': AppColors.primary,
    'in_progress': AppColors.warn,
    'escalated': AppColors.danger,
    'resolved': AppColors.success,
    'rejected': AppColors.ink3,
  };

  static const _backgrounds = {
    'submitted': AppColors.infoSoft,
    'assigned': AppColors.primarySoft,
    'in_progress': AppColors.warnSoft,
    'escalated': AppColors.dangerSoft,
    'resolved': AppColors.successSoft,
    'rejected': AppColors.canvas,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? AppColors.ink3;
    final background = _backgrounds[status] ?? AppColors.canvas;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _labels[status] ?? status,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class PriorityPill extends StatelessWidget {
  const PriorityPill(this.priority, {super.key, this.compact = false});

  final String priority;
  final bool compact;

  static const _labels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'critical': 'Critical',
  };

  static const _colors = {
    'low': AppColors.ink3,
    'medium': AppColors.warn,
    'high': Color(0xFFB45309),
    'critical': AppColors.danger,
  };

  static const _backgrounds = {
    'low': AppColors.canvas,
    'medium': AppColors.warnSoft,
    'high': AppColors.warnSoft,
    'critical': AppColors.dangerSoft,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[priority] ?? AppColors.ink3;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _backgrounds[priority] ?? AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        _labels[priority] ?? priority,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.tone = AppColors.primary,
    this.soft = AppColors.primarySoft,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final Color tone;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.ink,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load this view',
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
    );
  }
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 44),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class CivicField extends StatelessWidget {
  const CivicField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(hint!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
