import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/demo_data.dart';

class ComplaintDetailScreen extends StatelessWidget {
  final String complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  Widget build(BuildContext context) {
    final complaint = DemoData.complaints.firstWhere(
      (c) => c.id == complaintId,
      orElse: () => DemoData.complaints.first,
    );

    final df = DateFormat('d MMM yyyy, h:mm a');

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.surfaceWhite,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
            ),
            title: Text(
              complaint.id,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.sp16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Demo banner ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppTheme.sp8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.science_outlined,
                            size: 12, color: AppTheme.infoBlue),
                        const SizedBox(width: 6),
                        Text(
                          'DEMO DATA — Sample complaint for UI demonstration',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.infoBlue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp16),

                  // ── Header card ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppTheme.sp20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: AppTheme.shadowSm,
                      border: Border.all(color: AppTheme.borderGray200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                complaint.title,
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        Wrap(
                          spacing: AppTheme.sp8,
                          runSpacing: AppTheme.sp8,
                          children: [
                            StatusBadge(status: complaint.statusKey),
                            SeverityBadge(severity: complaint.severityLabel),
                            _CategoryChip(label: complaint.categoryLabel),
                          ],
                        ),
                        const SizedBox(height: AppTheme.sp16),
                        Text(
                          complaint.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: AppTheme.sp16),
                        const Divider(height: 1),
                        const SizedBox(height: AppTheme.sp16),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: complaint.location,
                        ),
                        const SizedBox(height: AppTheme.sp12),
                        _DetailRow(
                          icon: Icons.schedule_outlined,
                          label: 'Submitted',
                          value: df.format(complaint.createdAt),
                        ),
                        if (complaint.dueAt != null) ...[
                          const SizedBox(height: AppTheme.sp12),
                          _DetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Response Deadline',
                            value: df.format(complaint.dueAt!),
                            valueColor: complaint.dueAt!.isBefore(DateTime.now())
                                ? AppTheme.errorRed
                                : AppTheme.successGreen,
                          ),
                        ],
                        if (complaint.assignedDepartment != null) ...[
                          const SizedBox(height: AppTheme.sp12),
                          _DetailRow(
                            icon: Icons.business_outlined,
                            label: 'Department',
                            value: complaint.assignedDepartment!,
                          ),
                        ],
                        if (complaint.assignedOfficer != null) ...[
                          const SizedBox(height: AppTheme.sp12),
                          _DetailRow(
                            icon: Icons.person_outlined,
                            label: 'Assigned Officer',
                            value: complaint.assignedOfficer!,
                          ),
                        ],
                        if (complaint.aiConfidence != null) ...[
                          const SizedBox(height: AppTheme.sp12),
                          _DetailRow(
                            icon: Icons.auto_awesome_outlined,
                            label: 'AI Confidence',
                            value:
                                '${(complaint.aiConfidence! * 100).toStringAsFixed(0)}% — Auto-classified',
                            valueColor: AppTheme.tealAccent,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp20),

                  // ── Map placeholder ─────────────────────────────────────
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.sp12),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGray100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.borderGray200),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined,
                              size: 40, color: AppTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'Map preview — Phase 3',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${complaint.latitude.toStringAsFixed(4)}, ${complaint.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp24),

                  // ── Escalation timeline ─────────────────────────────────
                  Text(
                    'Status Timeline',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.sp4),
                  Text(
                    'Complete audit history of this complaint',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  _Timeline(events: complaint.timeline),
                  const SizedBox(height: AppTheme.sp32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.tealAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
            color: AppTheme.tealAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.tealAccent,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textTertiary),
        const SizedBox(width: AppTheme.sp8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<DemoStatusEvent> events;
  const _Timeline({required this.events});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy, h:mm a');
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No timeline events',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textTertiary),
        ),
      );
    }
    return Column(
      children: events.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final isLast = i == events.length - 1;
        final color = AppTheme.statusColor(e.statusKey);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline line + dot
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: e.isEscalation
                            ? AppTheme.statusEscalated
                            : color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        e.isEscalation
                            ? Icons.arrow_upward_rounded
                            : Icons.circle,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppTheme.borderGray200,
                        ),
                      ),
                  ],
                ),
              ),
              // Event content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppTheme.sp12,
                    bottom: isLast ? 0 : AppTheme.sp20,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.sp12),
                    decoration: BoxDecoration(
                      color: e.isEscalation
                          ? AppTheme.statusEscalated.withValues(alpha: 0.06)
                          : AppTheme.surfaceWhite,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: e.isEscalation
                            ? AppTheme.statusEscalated.withValues(alpha: 0.2)
                            : AppTheme.borderGray200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: e.statusKey, compact: true),
                            if (e.isEscalation) ...[
                              const SizedBox(width: AppTheme.sp8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusEscalated
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                ),
                                child: const Text(
                                  '⚠ ESCALATED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.statusEscalated,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppTheme.sp8),
                        if (e.note != null)
                          Text(
                            e.note!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 12, color: AppTheme.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              e.actor,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              df.format(e.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// sp6 = 6.0 (used inline above)
