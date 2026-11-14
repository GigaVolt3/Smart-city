import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';
import '../complaints/complaint_detail_screen.dart';
import '../complaints/report_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user!;
    final analytics = ref.watch(analyticsProvider(30));
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.location_city_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 9),
            const Text('CivicAI',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Alerts',
            onPressed: () => ref.read(shellTabProvider.notifier).state = 3,
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: AppColors.danger,
              label: Text('$unread',
                  style: const TextStyle(fontSize: 9, color: Colors.white)),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 2),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                _initials(user.fullName),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(analyticsProvider);
          ref.invalidate(unreadCountProvider);
          await ref.read(analyticsProvider(30).future);
        },
        child: analytics.when(
          loading: () => const LoadingPane(),
          error: (error, _) => ListView(
            children: [
              ErrorPane(
                message: error.toString(),
                onRetry: () => ref.invalidate(analyticsProvider),
              ),
            ],
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
            children: [
              Text(
                '${_greeting()}, ${user.firstName}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('EEEE, d MMMM').format(DateTime.now())} · ${user.ward ?? 'City-wide'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              if (data.kpis.slaBreached > 0) _SlaBanner(data: data),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KpiTile(
                      label: 'Open cases',
                      value: '${data.kpis.open}',
                      hint:
                          '${data.kpis.criticalOpen} critical · ${data.kpis.escalated} escalated',
                      icon: Icons.monitor_heart_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiTile(
                      label: 'SLA breached',
                      value: '${data.kpis.slaBreached}',
                      hint: '${data.sla.atRisk} due within 24h',
                      icon: Icons.warning_amber_rounded,
                      tone: AppColors.danger,
                      soft: AppColors.dangerSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: KpiTile(
                      label: 'Resolution rate',
                      value: '${data.kpis.resolutionRate.toStringAsFixed(1)}%',
                      hint: '${data.kpis.resolved} of ${data.kpis.total} resolved',
                      icon: Icons.check_circle_outline_rounded,
                      tone: AppColors.success,
                      soft: AppColors.successSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiTile(
                      label: 'Avg. resolution',
                      value: formatHours(data.kpis.avgResolutionHours),
                      hint: 'Filing to verified closure',
                      icon: Icons.schedule_rounded,
                      tone: AppColors.info,
                      soft: AppColors.infoSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Cases needing attention',
                subtitle: 'Oldest open complaints past or near their SLA',
                action: TextButton(
                  onPressed: () {
                    ref.read(complaintFilterProvider.notifier).state =
                        const ComplaintFilter(overdue: true);
                    ref.read(shellTabProvider.notifier).state = 1;
                  },
                  child: const Text('View all'),
                ),
              ),
              const SizedBox(height: 10),
              const _OverdueList(),
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Ward pressure',
                subtitle: 'Open and breached cases across the busiest wards',
              ),
              const SizedBox(height: 10),
              _WardPressure(wards: data.wards),
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Recent movement',
                subtitle: 'Latest status changes in your scope',
              ),
              const SizedBox(height: 10),
              if (data.recentActivity.isEmpty)
                const CivicCard(
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No movement yet',
                    message: 'Status updates will appear here as officers act on cases.',
                  ),
                )
              else
                CivicCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.recentActivity.length; i++) ...[
                        _ActivityRow(item: data.recentActivity[i]),
                        if (i < data.recentActivity.length - 1)
                          const Divider(indent: 14, endIndent: 14),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const ReportScreen()),
                    );
                    if (created == true && context.mounted) {
                      ref.invalidate(complaintsProvider);
                      ref.invalidate(analyticsProvider);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                      ref.read(shellTabProvider.notifier).state = 1;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Complaint filed. Tracking is live.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Report a civic issue'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(shellTabProvider.notifier).state = 2,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Live map'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(shellTabProvider.notifier).state = 1,
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('All cases'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _SlaBanner extends ConsumerWidget {
  const _SlaBanner({required this.data});

  final AnalyticsOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: const Color(0xFFF0DFB8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.amberDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.kpis.slaBreached} complaints are past their resolution deadline.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amberDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${data.kpis.criticalOpen} critical open cases · ${data.sla.atRisk} due within 24 hours',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A5A18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.amberDeep,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                ref.read(complaintFilterProvider.notifier).state =
                    const ComplaintFilter(overdue: true);
                ref.read(shellTabProvider.notifier).state = 1;
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Review queue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueList extends ConsumerWidget {
  const _OverdueList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(_homeOverdueProvider);
    return future.when(
      loading: () => const CivicCard(child: LoadingPane()),
      error: (error, _) => CivicCard(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load the queue',
          message: error.toString(),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(_homeOverdueProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const CivicCard(
            child: EmptyState(
              icon: Icons.verified_outlined,
              title: 'Nothing past SLA',
              message: 'Every open case in your scope is inside its deadline.',
            ),
          );
        }
        return CivicCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < page.items.length; i++) ...[
                _ComplaintRow(complaint: page.items[i]),
                if (i < page.items.length - 1)
                  const Divider(indent: 16, endIndent: 16),
              ],
            ],
          ),
        );
      },
    );
  }
}

final _homeOverdueProvider = FutureProvider.autoDispose<ComplaintPage>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    throw Exception('Sign in to load the queue.');
  }
  return ref.watch(apiProvider).complaints(overdue: true, limit: 4);
});

class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ComplaintDetailScreen(complaintId: complaint.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complaint.number,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                StatusPill(complaint.status, compact: true),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              complaint.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                PriorityPill(complaint.priority, compact: true),
                const SizedBox(width: 7),
                Text(
                  'Overdue ${dueParts(complaint.dueAt).value}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    complaint.ward,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.ink3,
                    ),
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

class _WardPressure extends StatelessWidget {
  const _WardPressure({required this.wards});

  final List<CountRow> wards;

  @override
  Widget build(BuildContext context) {
    final rows = [...wards]..sort((a, b) => b.count.compareTo(a.count));
    final visible = rows.take(4).toList();
    if (visible.isEmpty) {
      return const CivicCard(
        child: EmptyState(
          icon: Icons.map_outlined,
          title: 'No ward data yet',
          message: 'Ward workload appears after complaints are filed.',
        ),
      );
    }
    final max = visible.first.count == 0 ? 1 : visible.first.count;
    return CivicCard(
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    visible[i].label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${visible[i].count}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: visible[i].count / max,
                minHeight: 6,
                backgroundColor: AppColors.canvas,
                color: i == 0 ? AppColors.danger : AppColors.primary,
              ),
            ),
            if (i < visible.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(complaintId: item.complaintId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(item.newStatus, compact: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.actor} · ${relativeTime(item.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
