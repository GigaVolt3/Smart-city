import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user!;
    final lookups = ref.watch(lookupsProvider).valueOrNull;
    final department = lookups?.departmentById(user.departmentId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Profile & settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          CivicCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    _initials(user.fullName),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _Tag(label: user.roleLabel),
                          if (department != null) ...[
                            const SizedBox(width: 6),
                            Flexible(child: _Tag(label: department.name)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Account facts',
                  subtitle: 'Shown on complaints you file or act on',
                ),
                const SizedBox(height: 8),
                InfoRow(label: 'Phone', value: user.phoneNumber ?? 'Not set'),
                InfoRow(label: 'Ward', value: user.ward ?? 'Not assigned'),
                InfoRow(
                  label: 'Department',
                  value: department?.name ?? 'Unassigned',
                ),
                InfoRow(label: 'Role', value: user.roleLabel),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CivicCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: AppColors.primary, size: 21),
                  title: const Text('Edit personal details'),
                  subtitle: const Text('Name, phone number and ward'),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.ink3),
                  onTap: () => _openEditSheet(context, ref, user),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.primary, size: 21),
                  title: const Text('Change password'),
                  subtitle: const Text('Use at least 8 characters'),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.ink3),
                  onTap: () => _openPasswordSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Session'),
                const SizedBox(height: 6),
                Text(
                  'Signing out clears the access tokens stored on this device. '
                  'Unsaved form content will be lost.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out of CivicAI'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  'CivicAI mobile · v1.2.0',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  ref.watch(apiProvider).baseUrl,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _EditProfileSheet(user: user),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  Future<void> _openPasswordSheet(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _PasswordSheet(),
    );
    if (saved == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content:
            const Text('You will need your password to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink2,
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final User user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phoneNumber);
  late String? _ward = widget.user.ward;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            fullName: _name.text.trim(),
            phoneNumber: _phone.text.trim(),
            ward: _ward,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + insets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Edit personal details',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CivicField(
              label: 'Full name',
              required: true,
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    (value == null || value.trim().length < 2)
                        ? 'Enter your full name'
                        : null,
              ),
            ),
            const SizedBox(height: 14),
            CivicField(
              label: 'Phone number',
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 14),
            CivicField(
              label: 'Ward',
              child: DropdownButtonFormField<String>(
                initialValue: _ward,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('No ward assigned'),
                  ),
                  ...kWards.map((ward) => DropdownMenuItem(
                        value: ward,
                        child: Text(ward, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) => setState(() => _ward = value),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + insets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Change password',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CivicField(
              label: 'Current password',
              required: true,
              child: TextFormField(
                controller: _current,
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            CivicField(
              label: 'New password',
              required: true,
              hint: 'At least 8 characters',
              child: TextFormField(
                controller: _next,
                obscureText: true,
                validator: (value) => (value == null || value.length < 8)
                    ? 'Use at least 8 characters'
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            CivicField(
              label: 'Confirm new password',
              required: true,
              child: TextFormField(
                controller: _confirm,
                obscureText: true,
                validator: (value) => value != _next.text
                    ? 'Passwords do not match'
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
