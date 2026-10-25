import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/complaints/presentation/screens/complaints_list_screen.dart';
import '../../features/complaints/presentation/screens/submit_complaint_screen.dart';
import '../../features/complaints/presentation/screens/complaint_detail_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

/// Route names — use these constants to avoid magic strings.
abstract class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const myComplaints = '/complaints';
  static const submitComplaint = '/complaints/submit';
  static const complaintDetail = '/complaints/:id';
  static const notifications = '/notifications';
  static const profile = '/profile';

  static String complaintDetailPath(String id) => '/complaints/$id';
}

/// Plain Riverpod provider — no code generation needed.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) => _buildPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (context, state) => _buildPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => _buildPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: Routes.register,
        pageBuilder: (context, state) => _buildPage(state, const RegisterScreen()),
      ),
      // Shell route for bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (context, state) => _buildPage(state, const HomeScreen()),
          ),
          GoRoute(
            path: Routes.myComplaints,
            pageBuilder: (context, state) =>
                _buildPage(state, const ComplaintsListScreen()),
          ),
          GoRoute(
            path: Routes.notifications,
            pageBuilder: (context, state) =>
                _buildPage(state, const NotificationsScreen()),
          ),
          GoRoute(
            path: Routes.profile,
            pageBuilder: (context, state) =>
                _buildPage(state, const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: Routes.submitComplaint,
        pageBuilder: (context, state) =>
            _buildPage(state, const SubmitComplaintScreen(), fullScreen: true),
      ),
      GoRoute(
        path: Routes.complaintDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildPage(state, ComplaintDetailScreen(complaintId: id));
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

CustomTransitionPage<void> _buildPage(
  GoRouterState state,
  Widget child, {
  bool fullScreen = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (fullScreen) {
        return SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        );
      }
      return FadeTransition(
        opacity: animation.drive(
          Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
        ),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}

/// Bottom navigation shell widget
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    (
      path: Routes.home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    (
      path: Routes.myComplaints,
      icon: Icons.list_alt_outlined,
      activeIcon: Icons.list_alt,
      label: 'Complaints',
    ),
    (
      path: Routes.notifications,
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      label: 'Alerts',
    ),
    (
      path: Routes.profile,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  void _onTap(int index, BuildContext context) {
    setState(() => _selectedIndex = index);
    context.go(_destinations[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => _onTap(i, context),
          items: _destinations
              .map(
                (d) => BottomNavigationBarItem(
                  icon: Icon(d.icon),
                  activeIcon: Icon(d.activeIcon),
                  label: d.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
