import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/demo_data.dart';

class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  ComplaintStatus? _selectedStatus;
  ComplaintCategory? _selectedCategory;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DemoComplaint> get _filtered {
    var list = DemoData.complaints;
    if (_selectedStatus != null) {
      list = list.where((c) => c.status == _selectedStatus).toList();
    }
    if (_selectedCategory != null) {
      list = list.where((c) => c.category == _selectedCategory).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(query) ||
                c.location.toLowerCase().contains(query),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final complaints = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              AppTheme.sp8,
              AppTheme.sp16,
              AppTheme.sp4,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search complaints…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Active filters
          if (_selectedStatus != null || _selectedCategory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp16,
                AppTheme.sp4,
                AppTheme.sp16,
                0,
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Filtered',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedStatus = null;
                      _selectedCategory = null;
                    }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Clear filters',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          // Demo banner
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.sp16,
              AppTheme.sp8,
              AppTheme.sp16,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sp12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined,
                      size: 13, color: AppTheme.infoBlue),
                  const SizedBox(width: 6),
                  Text(
                    'DEMO DATA — ${complaints.length} sample complaint(s)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.infoBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          // List
          Expanded(
            child: complaints.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.sp16,
                      0,
                      AppTheme.sp16,
                      AppTheme.sp32,
                    ),
                    itemCount: complaints.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.sp12),
                    itemBuilder: (context, i) {
                      final c = complaints[i];
                      return _ComplaintListCard(
                        complaint: c,
                        onTap: () => context
                            .go(Routes.complaintDetailPath(c.id)),
                      );
                    },
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
          'New Report',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedStatus: _selectedStatus,
        selectedCategory: _selectedCategory,
        onApply: (status, category) {
          setState(() {
            _selectedStatus = status;
            _selectedCategory = category;
          });
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: AppTheme.borderGray200),
          const SizedBox(height: AppTheme.sp16),
          Text(
            'No complaints found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            'Try adjusting your filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintListCard extends StatelessWidget {
  final DemoComplaint complaint;
  final VoidCallback onTap;

  const _ComplaintListCard({required this.complaint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGray100,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      DemoData.categories
                          .firstWhere(
                            (c) => c.category == complaint.category,
                            orElse: () => DemoData.categories.last,
                          )
                          .icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${complaint.id} • ${complaint.categoryLabel}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.sp8),
                StatusBadge(status: complaint.statusKey, compact: true),
              ],
            ),
            const SizedBox(height: AppTheme.sp12),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.sp12),
            Row(
              children: [
                _MetaItem(
                  icon: Icons.location_on_outlined,
                  text: complaint.location,
                  flex: 2,
                ),
                _MetaItem(
                  icon: Icons.calendar_today_outlined,
                  text: df.format(complaint.createdAt),
                ),
                if (complaint.escalationLevel > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: AppTheme.sp8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 12,
                          color: AppTheme.statusEscalated,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'L${complaint.escalationLevel}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.statusEscalated,
                          ),
                        ),
                      ],
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

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final int flex;

  const _MetaItem({required this.icon, required this.text, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final ComplaintStatus? selectedStatus;
  final ComplaintCategory? selectedCategory;
  final void Function(ComplaintStatus?, ComplaintCategory?) onApply;

  const _FilterSheet({
    this.selectedStatus,
    this.selectedCategory,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  ComplaintStatus? _status;
  ComplaintCategory? _category;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _category = widget.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTheme.sp24,
        AppTheme.sp16,
        AppTheme.sp24,
        MediaQuery.paddingOf(context).bottom + AppTheme.sp24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderGray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp20),
          Text('Filter Complaints',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.sp20),
          Text('Status',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  )),
          const SizedBox(height: AppTheme.sp8),
          Wrap(
            spacing: AppTheme.sp8,
            runSpacing: AppTheme.sp8,
            children: ComplaintStatus.values.map((s) {
              final key = DemoComplaint(
                id: '', title: '', description: '',
                category: ComplaintCategory.other,
                severity: ComplaintSeverity.low,
                status: s, location: '',
                latitude: 0, longitude: 0,
                createdAt: DateTime.now(),
              ).statusKey;
              final selected = _status == s;
              return FilterChip(
                label: Text(AppTheme.statusLabel(key)),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _status = selected ? null : s),
                selectedColor:
                    AppTheme.primaryNavy.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primaryNavy,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryNavy
                      : AppTheme.textSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.sp20),
          Text('Category',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  )),
          const SizedBox(height: AppTheme.sp8),
          Wrap(
            spacing: AppTheme.sp8,
            runSpacing: AppTheme.sp8,
            children: DemoData.categories.map((c) {
              final selected = _category == c.category;
              return FilterChip(
                label: Text('${c.icon} ${c.label}'),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _category = selected ? null : c.category),
                selectedColor:
                    AppTheme.tealAccent.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.tealAccent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppTheme.tealAccent
                      : AppTheme.textSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.sp24),
          ElevatedButton(
            onPressed: () {
              widget.onApply(_status, _category);
              Navigator.pop(context);
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}
