import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/demo_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = DemoData.demoUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Avatar + Name ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppTheme.surfaceWhite,
              padding: const EdgeInsets.all(AppTheme.sp32),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor:
                            AppTheme.primaryNavy.withValues(alpha: 0.12),
                        child: Text(
                          user.name[0],
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.tealAccent,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sp12),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.sp4),
                  Text(
                    user.ward,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(
                          label: 'Total',
                          value: '${DemoData.stats.total}'),
                      Container(
                          width: 1, height: 32, color: AppTheme.borderGray200),
                      _StatItem(
                          label: 'Resolved',
                          value: '${DemoData.stats.resolved}'),
                      Container(
                          width: 1, height: 32, color: AppTheme.borderGray200),
                      _StatItem(
                          label: 'Pending',
                          value:
                              '${DemoData.stats.pending + DemoData.stats.inProgress}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sp8),

            // ── Account info ─────────────────────────────────────────────────
            _Section(
              title: 'Account',
              children: [
                _ProfileTile(
                  icon: Icons.phone_outlined,
                  label: 'Mobile',
                  value: user.phone,
                ),
                _ProfileTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email,
                ),
                _ProfileTile(
                  icon: Icons.location_on_outlined,
                  label: 'Ward',
                  value: user.ward,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),

            // ── Language ─────────────────────────────────────────────────────
            _Section(
              title: 'Language & Region',
              children: [
                _ProfileTile(
                  icon: Icons.translate_rounded,
                  label: 'Language',
                  value: 'English (India)',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textTertiary),
                  onTap: () => _showLanguagePicker(context),
                ),
                _ProfileTile(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: 'Bengaluru (Demo)',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),

            // ── Preferences ──────────────────────────────────────────────────
            _Section(
              title: 'Notifications',
              children: [
                _SwitchTile(
                  icon: Icons.notifications_outlined,
                  label: 'Push Notifications',
                  value: true,
                ),
                _SwitchTile(
                  icon: Icons.sms_outlined,
                  label: 'SMS Updates',
                  value: false,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),

            // ── About ────────────────────────────────────────────────────────
            _Section(
              title: 'About',
              children: [
                _ProfileTile(
                  icon: Icons.info_outline_rounded,
                  label: 'App Version',
                  value: '1.0.0 (Phase 1 — Demo)',
                ),
                _ProfileTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textTertiary),
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textTertiary),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp8),

            // ── Sign out ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sp16,
                vertical: AppTheme.sp8,
              ),
              child: OutlinedButton.icon(
                onPressed: () => context.go(Routes.login),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ),
            const SizedBox(height: AppTheme.sp32),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            const SizedBox(height: AppTheme.sp16),
            const Text(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
            ...[
              ('🇬🇧', 'English (India)', true),
              ('🇮🇳', 'ಕನ್ನಡ (Kannada)', false),
            ].map(
              (lang) => ListTile(
                leading: Text(lang.$1,
                    style: const TextStyle(fontSize: 22)),
                title: Text(
                  lang.$2,
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
                trailing: lang.$3
                    ? const Icon(Icons.check_rounded,
                        color: AppTheme.tealAccent)
                    : Chip(
                        label: const Text('Phase 8',
                            style: TextStyle(
                                fontSize: 10, fontFamily: 'Inter')),
                        backgroundColor:
                            AppTheme.borderGray200,
                        padding: EdgeInsets.zero,
                      ),
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.sp16,
            AppTheme.sp12,
            AppTheme.sp16,
            AppTheme.sp8,
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          color: AppTheme.surfaceWhite,
          child: Column(
            children: children.asMap().entries.map((e) {
              return Column(
                children: [
                  e.value,
                  if (e.key < children.length - 1)
                    const Divider(
                      height: 1,
                      indent: AppTheme.sp16 + 40,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppTheme.primaryNavy),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: value != null
          ? Text(
              value!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool value;
  const _SwitchTile(
      {required this.icon, required this.label, required this.value});

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon, size: 20, color: AppTheme.primaryNavy),
      title: Text(
        widget.label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: Switch.adaptive(
        value: _value,
        onChanged: (v) => setState(() => _value = v),
        activeColor: AppTheme.tealAccent,
      ),
    );
  }
}
