import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final _demoNotifications = [
    (
      icon: Icons.arrow_upward_rounded,
      color: AppTheme.statusEscalated,
      title: 'Complaint Escalated',
      body: 'CMP-2024-001 has been escalated to the Supervisor level due to missed deadline.',
      time: '2 hours ago',
      unread: true,
    ),
    (
      icon: Icons.check_circle_outline_rounded,
      color: AppTheme.statusResolved,
      title: 'Complaint Resolved',
      body: 'CMP-2024-003: Streetlight repair at Koramangala 5th Block has been resolved.',
      time: '1 day ago',
      unread: true,
    ),
    (
      icon: Icons.engineering_rounded,
      color: AppTheme.statusInProgress,
      title: 'Officer Assigned',
      body: 'Priya Sharma has been assigned to your garbage complaint at Indiranagar.',
      time: '2 days ago',
      unread: false,
    ),
    (
      icon: Icons.info_outline_rounded,
      color: AppTheme.infoBlue,
      title: 'Department Assigned',
      body: 'Your complaint CMP-2024-004 has been assigned to Water & Sewerage dept.',
      time: '3 days ago',
      unread: false,
    ),
    (
      icon: Icons.campaign_rounded,
      color: AppTheme.tealAccent,
      title: 'Complaint Received',
      body: 'We\'ve received your complaint CMP-2024-005 and are processing it.',
      time: '5 days ago',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _demoNotifications.where((n) => n.unread).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {},
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: Column(
        children: [
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
                  horizontal: AppTheme.sp12, vertical: 6),
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
                    'DEMO DATA — Sample notifications. Real push via FCM in Phase 4.',
                    style: TextStyle(fontSize: 11, color: AppTheme.infoBlue),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.sp16),
              itemCount: _demoNotifications.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.sp8),
              itemBuilder: (context, i) {
                final n = _demoNotifications[i];
                return Container(
                  decoration: BoxDecoration(
                    color: n.unread
                        ? AppTheme.primaryNavy.withValues(alpha: 0.04)
                        : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: n.unread
                          ? AppTheme.primaryNavy.withValues(alpha: 0.15)
                          : AppTheme.borderGray200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppTheme.sp16),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: n.color.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(n.icon, color: n.color, size: 22),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: n.unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (n.unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          n.body,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
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
