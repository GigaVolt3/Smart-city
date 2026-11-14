import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';
import 'complaint_detail_screen.dart';

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final filter = ref.read(complaintFilterProvider);
      ref.read(complaintFilterProvider.notifier).state =
          filter.copyWith(search: value);
    });
  }

  void _setStatus(String? status) {
    final filter = ref.read(complaintFilterProvider);
    ref.read(complaintFilterProvider.notifier).state = status == null
        ? filter.copyWith(clearStatus: true)
        : filter.copyWith(status: status);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(complaintFilterProvider);
    final complaints = ref.watch(complaintsProvider);
    final lookups = ref.watch(lookupsProvider).valueOrNull;
    final isStaff = ref.watch(authProvider).user?.isStaff ?? false;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Complaint queue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(complaintsProvider);
              ref.invalidate(lookupsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search reference, title or address',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: !filter.isActive,
                  onTap: () {
                    ref.read(complaintFilterProvider.notifier).state =
                        const ComplaintFilter();
                    _search.clear();
                  },
                ),
                _FilterChip(
                  label: 'Past SLA',
                  selected: filter.overdue,
                  tone: AppColors.danger,
                  onTap: () {
                    final current = ref.read(complaintFilterProvider);
                    ref.read(complaintFilterProvider.notifier).state =
                        current.copyWith(overdue: !current.overdue);
                  },
                ),
                if (isStaff)
                  _FilterChip(
                    label: 'Assigned to me',
                    selected: filter.assignedToMe,
                    onTap: () {
                      final current = ref.read(complaintFilterProvider);
                      ref.read(complaintFilterProvider.notifier).state =
                          current.copyWith(
                              assignedToMe: !current.assignedToMe);
                    },
                  ),
                _FilterChip(
                  label: 'Submitted',
                  selected: filter.status == 'submitted',
                  onTap: () => _setStatus(
                      filter.status == 'submitted' ? null : 'submitted'),
                ),
                _FilterChip(
                  label: 'In progress',
                  selected: filter.status == 'in_progress',
                  onTap: () => _setStatus(
                      filter.status == 'in_progress' ? null : 'in_progress'),
                ),
                _FilterChip(
                  label: 'Escalated',
                  selected: filter.status == 'escalated',
                  tone: AppColors.danger,
                  onTap: () => _setStatus(
                      filter.status == 'escalated' ? null : 'escalated'),
                ),
                _FilterChip(
                  label: 'Resolved',
                  selected: filter.status == 'resolved',
                  onTap: () => _setStatus(
                      filter.status == 'resolved' ? null : 'resolved'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: complaints.when(
              loading: () => const LoadingPane(),
              error: (error, _) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ErrorPane(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(complaintsProvider),
                  ),
                ],
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(complaintsProvider);
                      await ref.read(complaintsProvider.future);
                    },
                    child: ListView(
                      children: [
                        const SizedBox(height: 30),
                        EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No complaints match',
                          message: filter.isActive
                              ? 'Try clearing the filters or searching a different reference.'
                              : 'File the first complaint in your ward using the report button.',
                          action: filter.isActive
                              ? OutlinedButton(
                                  onPressed: () {
                                    _search.clear();
                                    ref
                                        .read(complaintFilterProvider.notifier)
                                        .state = const ComplaintFilter();
                                  },
                                  child: const Text('Clear filters'),
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(complaintsProvider);
                    await ref.read(complaintsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${page.total} case${page.total == 1 ? '' : 's'} in your scope',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      final complaint = page.items[index - 1];
                      return _ComplaintCard(
                        complaint: complaint,
                        department: lookups?.departmentById(complaint.departmentId),
                        category: lookups?.categoryById(complaint.categoryId),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.35) : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? accent : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.complaint,
    this.department,
    this.category,
  });

  final Complaint complaint;
  final Department? department;
  final ComplaintCategory? category;

  @override
  Widget build(BuildContext context) {
    final due = dueParts(complaint.dueAt);
    return CivicCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ComplaintDetailScreen(complaintId: complaint.id),
        ),
      ),
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
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              StatusPill(complaint.status, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            complaint.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.ink3),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [complaint.ward, category?.name ?? department?.name]
                      .whereType<String>()
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              PriorityPill(complaint.priority, compact: true),
              if (complaint.isOpen) ...[
                const SizedBox(width: 8),
                Text(
                  due.overdue ? 'Overdue ${due.value}' : '${due.value} left',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color:
                        due.overdue ? AppColors.danger : AppColors.ink3,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                relativeTime(complaint.createdAt),
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
