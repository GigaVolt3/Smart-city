import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../complaints/complaints_screen.dart';
import '../complaints/report_screen.dart';
import '../home/home_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    ComplaintsScreen(),
    MapScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  Future<void> _openReport() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReportScreen()),
    );
    if (created == true && mounted) {
      ref.invalidate(complaintsProvider);
      ref.invalidate(analyticsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      setState(() => _index = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint filed. Tracking is live.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _openReport,
        tooltip: 'Report an issue',
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
          color: AppColors.surface,
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) => setState(() => _index = value),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Cases',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map_rounded),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: AppColors.danger,
                  label: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: AppColors.danger,
                  label: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                  child: const Icon(Icons.notifications_rounded),
                ),
                label: 'Alerts',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
