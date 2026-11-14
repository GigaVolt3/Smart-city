import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../shell/app_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.booting) {
      return const _BootScreen();
    }
    if (auth.user == null) {
      return const AuthScreen();
    }
    return const AppShell();
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(size: 56, dark: true),
            SizedBox(height: 18),
            Text(
              'CivicAI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'MUNICIPAL OPERATIONS',
              style: TextStyle(
                color: Color(0xFF8FB3A8),
                fontSize: 10.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 26),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _registering = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          _BrandMark(size: 44),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CivicAI',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'MUNICIPAL OPERATIONS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      Text(
                        _registering
                            ? 'Create your citizen account'
                            : 'Welcome back',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontSize: 27),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _registering
                            ? 'Report civic issues, follow progress and get notified when your ward resolves them.'
                            : 'Sign in to file complaints, follow resolution progress and manage escalations.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (_registering)
                        RegisterPanel(
                          onSwitch: () => setState(() => _registering = false),
                        )
                      else
                        LoginPanel(
                          onSwitch: () => setState(() => _registering = true),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LoginPanel extends ConsumerStatefulWidget {
  const LoginPanel({super.key, required this.onSwitch});

  final VoidCallback onSwitch;

  @override
  ConsumerState<LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends ConsumerState<LoginPanel> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .signIn(_email.text.trim(), _password.text);
    if (!ok && mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  void _fillDemo() {
    _email.text = 'citizen@demo.civicai';
    _password.text = 'DemoPass1!';
    // Clear any "required field" errors left over from an earlier submit.
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CivicField(
            label: 'Email address',
            required: true,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email address';
                }
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),
          CivicField(
            label: 'Password',
            required: true,
            child: TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: auth.busy ? null : _submit,
              child: auth.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Sign in'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onSwitch,
                  child: const Text('New resident? Create an account'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: const Color(0xFFCFE5DE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.science_outlined,
                    size: 18, color: AppColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demo environment',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Citizen, officer, supervisor and admin accounts use the password DemoPass1!',
                        style: TextStyle(fontSize: 12, color: AppColors.ink2),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _fillDemo,
                        child: const Text(
                          'Use citizen demo credentials',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const ServerTargetTile(),
        ],
      ),
    );
  }
}

class RegisterPanel extends ConsumerStatefulWidget {
  const RegisterPanel({super.key, required this.onSwitch});

  final VoidCallback onSwitch;

  @override
  ConsumerState<RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends ConsumerState<RegisterPanel> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _ward;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authProvider.notifier).register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          ward: _ward,
        );
    if (!ok && mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CivicField(
            label: 'Full name',
            required: true,
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
              ),
              validator: (value) => (value == null || value.trim().length < 2)
                  ? 'Enter your full name'
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          CivicField(
            label: 'Email address',
            required: true,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email address';
                }
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),
          CivicField(
            label: 'Phone number',
            child: TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone_outlined, size: 19),
              ),
            ),
          ),
          const SizedBox(height: 14),
          CivicField(
            label: 'Ward',
            child: DropdownButtonFormField<String>(
              initialValue: _ward,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select your ward',
                prefixIcon: Icon(Icons.location_on_outlined, size: 19),
              ),
              items: kWards
                  .map((ward) => DropdownMenuItem(
                        value: ward,
                        child: Text(ward, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _ward = value),
            ),
          ),
          const SizedBox(height: 14),
          CivicField(
            label: 'Password',
            required: true,
            hint: 'At least 6 characters',
            child: TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Create a password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Use at least 6 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: auth.busy ? null : _submit,
              child: auth.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create account'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onSwitch,
                  child: const Text('Already registered? Sign in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 44, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF172A25) : AppColors.surface,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: dark ? const Color(0xFF2A403A) : AppColors.line,
        ),
      ),
      child: Icon(
        Icons.location_city_rounded,
        size: size * 0.52,
        color: dark ? AppColors.amber : AppColors.primary,
      ),
    );
  }
}

/// Lets the user point the installed app at whichever host is running the
/// CivicAI API. Sideloaded builds default to the emulator loopback address,
/// which is useless on a physical phone, so the target is editable here.
class ServerTargetTile extends ConsumerStatefulWidget {
  const ServerTargetTile({super.key});

  @override
  ConsumerState<ServerTargetTile> createState() => _ServerTargetTileState();
}

class _ServerTargetTileState extends ConsumerState<ServerTargetTile> {
  Future<void> _edit() async {
    final api = ref.read(apiProvider);
    final controller = TextEditingController(text: api.baseUrl);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: '192.168.1.20:8000',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use 10.0.2.2:8000 for the Android emulator, or your computer '
              'LAN address (for example 192.168.1.20:8000) for a phone on the '
              'same Wi-Fi.',
              style: TextStyle(fontSize: 12, color: AppColors.ink3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final prefs = SharedPreferences.getInstance();
              prefs.then((value) => value.remove(ApiClient.prefsKey));
              Navigator.of(context).pop(ApiClient.defaultBaseUrl());
            },
            child: const Text('Use default'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null) return;

    final normalized = ApiClient.normalizeBaseUrl(saved);
    api.setBaseUrl(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.prefsKey, normalized);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Backend set to $normalized')));
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(apiProvider).baseUrl;
    return InkWell(
      onTap: _edit,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.dns_outlined, size: 16, color: AppColors.ink3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Server: $baseUrl',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink3,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text(
              'Change',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
