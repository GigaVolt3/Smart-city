import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.campaign_rounded,
      title: 'Report Civic Issues',
      description:
          'Photograph potholes, garbage dumps, broken streetlights and water leaks. Submit a complaint in under 60 seconds with GPS location.',
      color: AppTheme.primaryNavy,
    ),
    (
      icon: Icons.auto_graph_rounded,
      title: 'AI-Powered Classification',
      description:
          'Our AI automatically classifies your complaint, detects duplicates and routes it to the right department for faster resolution.',
      color: AppTheme.tealAccent,
    ),
    (
      icon: Icons.escalator_warning_rounded,
      title: 'Auto-Escalation Engine',
      description:
          'Unresolved complaints are automatically escalated through the authority chain. Nothing slips through the cracks.',
      color: Color(0xFF7C3AED),
    ),
    (
      icon: Icons.fact_check_rounded,
      title: 'Verified Resolution',
      description:
          'Officers submit before-and-after evidence. You confirm the fix, or raise a dispute if the issue persists.',
      color: AppTheme.successGreen,
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go(Routes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray50,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp16,
                  vertical: AppTheme.sp8,
                ),
                child: TextButton(
                  onPressed: () => context.go(Routes.login),
                  child: const Text('Skip'),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sp32,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          width: size.width * 0.5,
                          height: size.width * 0.5,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              page.icon,
                              size: size.width * 0.22,
                              color: page.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp48),
                        Text(
                          page.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.sp16),
                        Text(
                          page.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.6,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots + button
            Padding(
              padding: const EdgeInsets.all(AppTheme.sp32),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppTheme.primaryNavy
                              : AppTheme.borderGray200,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp32),
                  // CTA button
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _page < _pages.length - 1 ? 'Next' : 'Get Started',
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  if (_page == _pages.length - 1)
                    TextButton(
                      onPressed: () => context.go(Routes.login),
                      child: const Text('Already have an account? Sign in'),
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
