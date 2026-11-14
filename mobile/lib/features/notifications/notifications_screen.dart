import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';
import '../complaints/complaint_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Alerts'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(apiProvider).markAllNotificationsRead();
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Mark all read'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: feed.when(
        loading: () => const LoadingPane(),
        error: (error, _) => ListView(
          children: [
            ErrorPane(
              message: error.toString(),
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          ],
        ),
        data: (data) {
          final items = _unreadOnly
              ? data.items.where((item) => !item.isRead).toList()
              : data.items;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
              children: [
                Row(
                  children: [
                    _Toggle(
                      label: 'All',
                      selected: !_unreadOnly,
                      onTap: () => setState(() => _unreadOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _Toggle(
                      label: 'Unread (${data.unreadCount})',
                      selected: _unreadOnly,
                      onTap: () => setState(() => _unreadOnly = true),
                    ),
                    const Spacer(),
                    Text(
                      '${data.total} alert${data.total == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const CivicCard(
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'You are up to date',
                      message:
                          'Status changes and escalations on your cases will appear here.',
                    ),
                  )
                else
                  for (final item in items) ...[
                    _NotificationCard(item: item),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? const Color(0xFFC8E2D9) : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primaryDark : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  IconData get _icon => switch (item.type) {
        'escalation' => Icons.trending_up_rounded,
        'assignment' => Icons.person_add_alt_1_outlined,
        'status_change' => Icons.sync_rounded,
        _ => Icons.notifications_none_rounded,
      };

  Color get _tone => switch (item.type) {
        'escalation' => AppColors.danger,
        'assignment' => AppColors.primary,
        'status_change' => AppColors.info,
        _ => AppColors.ink3,
      };

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!item.isRead) {
      try {
        await ref.read(apiProvider).markNotificationRead(item.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      } catch (_) {
        // Opening the complaint is still useful if marking fails.
      }
    }
    if (item.complaintId != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ComplaintDetailScreen(complaintId: item.complaintId!),
        ),
      );
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CivicCard(
      onTap: () => _open(context, ref),
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.isRead
                  ? AppColors.canvas
                  : _tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(_icon,
                size: 17, color: item.isRead ? AppColors.ink3 : _tone),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              item.isRead ? FontWeight.w500 : FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      relativeTime(item.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.ink3),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.ink2,
                  ),
                ),
                if (item.complaintId != null) ...[
                  const SizedBox(height: 7),
                  const Row(
                    children: [
                      Text(
                        'Open complaint',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.primaryDark),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete alert',
            onPressed: () async {
              try {
                await ref.read(apiProvider).deleteNotification(item.id);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
