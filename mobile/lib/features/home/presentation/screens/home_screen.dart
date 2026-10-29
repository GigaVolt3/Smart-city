import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../features/complaints/data/models/demo_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = DemoData.demoUser;
    final stats = DemoData.stats;
    final recentComplaints = DemoData.complaints.take(3).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray50,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primaryNavy,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: AppTheme.primaryNavy,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.sp24,
                  AppTheme.sp64,
                  AppTheme.sp24,
                  AppTheme.sp16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good ${_greeting()}, ${user.name.split(' ').first}!',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14, color: Colors.white60),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.ward,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppTheme.tealAccent.withValues(alpha: 0.3),
                          child: Text(
                            user.name[0],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            title: const Text(
              'CivicAI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () => context.go(Routes.notifications),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.sp16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Demo banner ──────────────────────────────────────────
                  _DemoBanner(),
                  const SizedBox(height: AppTheme.sp16),

                  // ── Stats grid ───────────────────────────────────────────
                  _StatsGrid(stats: stats),
                  const SizedBox(height: AppTheme.sp24),

                  // ── Quick report CTA ─────────────────────────────────────
                  _QuickReportCard(),
                  const SizedBox(height: AppTheme.sp24),

                  // ── Categories ───────────────────────────────────────────
                  Text(
                    'Report by Category',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.sp12),
                  _CategoryGrid(),
                  const SizedBox(height: AppTheme.sp24),

                  // ── Recent complaints ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Recent Complaints',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(Routes.myComplaints),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sp8),
                  ...recentComplaints.map(
                    (c) => _ComplaintCard(
                      complaint: c,
                      onTap: () => context.go(
                        Routes.complaintDetailPath(c.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp32),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.submitComplaint),
        backgroundColor: AppTheme.tealAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Report Issue',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _DemoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: AppTheme.infoBlue),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Text(
              '⚠️  DEMO DATA — Showing sample complaints. Connect to backend in Phase 3.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.infoBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ({int total, int pending, int inProgress, int escalated, int resolved}) stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'Total', value: stats.total, color: AppTheme.primaryNavy, icon: Icons.list_alt_rounded),
      (label: 'Pending', value: stats.pending, color: AppTheme.statusPending, icon: Icons.hourglass_empty_rounded),
      (label: 'In Progress', value: stats.inProgress, color: AppTheme.statusInProgress, icon: Icons.engineering_rounded),
      (label: 'Escalated', value: stats.escalated, color: AppTheme.statusEscalated, icon: Icons.warning_amber_rounded),
      (label: 'Resolved', value: stats.resolved, color: AppTheme.statusResolved, icon: Icons.check_circle_outline_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppTheme.sp12,
        crossAxisSpacing: AppTheme.sp12,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.shadowSm,
            border: Border.all(color: AppTheme.borderGray200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: item.color, size: 22),
              const SizedBox(height: 6),
              Text(
                '${item.value}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickReportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(Routes.submitComplaint),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.sp20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryNavy, AppTheme.primaryNavyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryNavy.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spot a problem?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Report it in under 60 seconds. Our AI routes it to the right department instantly.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sp16,
                      vertical: AppTheme.sp8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Submit Complaint',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.sp12),
            Icon(
              Icons.campaign_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = DemoData.categories.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppTheme.sp8,
        crossAxisSpacing: AppTheme.sp8,
        childAspectRatio: 1.0,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return GestureDetector(
          onTap: () => context.go(Routes.submitComplaint),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderGray200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  cat.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final DemoComplaint complaint;
  final VoidCallback onTap;

  const _ComplaintCard({required this.complaint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM, h:mm a');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.sp12),
        padding: const EdgeInsets.all(AppTheme.sp16),
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
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.sp8),
                StatusBadge(status: complaint.statusKey, compact: true),
              ],
            ),
            const SizedBox(height: AppTheme.sp4),
            Text(
              complaint.categoryLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.tealAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.sp8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    complaint.location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatter.format(complaint.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            if (complaint.escalationLevel > 0) ...[
              const SizedBox(height: AppTheme.sp8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.statusEscalated.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward_rounded,
                        size: 12, color: AppTheme.statusEscalated),
                    const SizedBox(width: 4),
                    Text(
                      'Escalation Level ${complaint.escalationLevel}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.statusEscalated,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
