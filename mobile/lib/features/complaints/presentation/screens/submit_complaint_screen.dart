import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/civicai_text_field.dart';
import '../../data/models/demo_data.dart';

/// Multi-step complaint submission form.
/// Phase 1: UI only — no real backend call. Clearly labelled.
class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();

  // Form state
  ComplaintCategory? _category;
  ComplaintSeverity _severity = ComplaintSeverity.medium;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController(
    text: '12.9716, 77.5946 — MG Road, Bengaluru',
  );
  bool _useCurrentLocation = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  static const _steps = ['Category', 'Details', 'Location', 'Review'];

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSuccess();
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.successGreen,
                size: 40,
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
            const Text(
              'Complaint Submitted!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.sp8),
            const Text(
              '⚠️  DEMO MODE — In Phase 3, this will create a real complaint and auto-assign a department.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.sp8),
            Container(
              padding: const EdgeInsets.all(AppTheme.sp12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceGray100,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Column(
                children: [
                  _SuccessDetail(
                    icon: Icons.tag_rounded,
                    label: 'Complaint ID',
                    value: 'CMP-DEMO-${DateTime.now().millisecondsSinceEpoch % 9999}',
                  ),
                  const SizedBox(height: 6),
                  _SuccessDetail(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Classification',
                    value: _category?.name.toUpperCase() ?? 'OTHER',
                  ),
                  const SizedBox(height: 6),
                  _SuccessDetail(
                    icon: Icons.business_outlined,
                    label: 'Dept. Assigned',
                    value: 'Roads & Infrastructure (Demo)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sp20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray50,
      appBar: AppBar(
        title: const Text('Report an Issue'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(currentStep: _step, steps: _steps),
          const Divider(height: 1),
          // Content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.sp20),
                child: [
                  _StepCategory(
                    selected: _category,
                    onSelect: (c) => setState(() => _category = c),
                  ),
                  _StepDetails(
                    titleController: _titleController,
                    descController: _descController,
                    severity: _severity,
                    onSeverityChange: (s) => setState(() => _severity = s),
                  ),
                  _StepLocation(
                    controller: _locationController,
                    useCurrentLocation: _useCurrentLocation,
                    onToggle: (v) =>
                        setState(() => _useCurrentLocation = v),
                  ),
                  _StepReview(
                    category: _category,
                    severity: _severity,
                    title: _titleController.text,
                    description: _descController.text,
                    location: _locationController.text,
                  ),
                ][_step],
              ),
            ),
          ),
          // Bottom nav
          _BottomNav(
            step: _step,
            totalSteps: _steps.length,
            isSubmitting: _isSubmitting,
            onBack: () => setState(() => _step--),
            onNext: () {
              if (_step == 0 && _category == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a category')),
                );
                return;
              }
              if (_step < _steps.length - 1) {
                setState(() => _step++);
              } else {
                _submit();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const _StepIndicator({required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceWhite,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp20,
        vertical: AppTheme.sp12,
      ),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final label = e.value;
          final active = i == currentStep;
          final done = i < currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        decoration: BoxDecoration(
                          color: done || active
                              ? AppTheme.primaryNavy
                              : AppTheme.borderGray200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active
                              ? AppTheme.primaryNavy
                              : AppTheme.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StepCategory extends StatelessWidget {
  final ComplaintCategory? selected;
  final void Function(ComplaintCategory) onSelect;

  const _StepCategory({this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What type of issue are you reporting?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.sp4),
        Text(
          'Our AI will verify the category automatically.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppTheme.sp12,
            crossAxisSpacing: AppTheme.sp12,
            childAspectRatio: 2.2,
          ),
          itemCount: DemoData.categories.length,
          itemBuilder: (context, i) {
            final cat = DemoData.categories[i];
            final isSelected = selected == cat.category;
            return GestureDetector(
              onTap: () => onSelect(cat.category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(AppTheme.sp12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryNavy.withValues(alpha: 0.08)
                      : AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryNavy
                        : AppTheme.borderGray200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(cat.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: AppTheme.sp8),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryNavy
                              : AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primaryNavy, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StepDetails extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descController;
  final ComplaintSeverity severity;
  final void Function(ComplaintSeverity) onSeverityChange;

  const _StepDetails({
    required this.titleController,
    required this.descController,
    required this.severity,
    required this.onSeverityChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Describe the issue',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.sp20),
        CivicAITextField(
          controller: titleController,
          label: 'Title *',
          hint: 'e.g. Large pothole on MG Road near signal',
          prefixIcon: Icons.title_rounded,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
        ),
        const SizedBox(height: AppTheme.sp16),
        CivicAITextField(
          controller: descController,
          label: 'Description *',
          hint:
              'Describe the problem in detail. Include landmark references, duration, safety concerns…',
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          validator: (v) =>
              (v == null || v.trim().length < 10)
                  ? 'Describe the issue in at least 10 characters'
                  : null,
        ),
        const SizedBox(height: AppTheme.sp20),
        Text('Severity',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTheme.sp4),
        Text(
          'How urgent is this issue?',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp12),
        Row(
          children: ComplaintSeverity.values.map((s) {
            final isSelected = severity == s;
            final color = switch (s) {
              ComplaintSeverity.low => AppTheme.successGreen,
              ComplaintSeverity.medium => AppTheme.infoBlue,
              ComplaintSeverity.high => AppTheme.warningAmber,
              ComplaintSeverity.critical => AppTheme.errorRed,
            };
            final label = switch (s) {
              ComplaintSeverity.low => 'Low',
              ComplaintSeverity.medium => 'Medium',
              ComplaintSeverity.high => 'High',
              ComplaintSeverity.critical => 'Critical',
            };
            return Expanded(
              child: GestureDetector(
                onTap: () => onSeverityChange(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: AppTheme.sp8),
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.sp8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.12)
                        : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: isSelected ? color : AppTheme.borderGray200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: isSelected ? color : AppTheme.textTertiary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? color : AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppTheme.sp20),
        // Photo placeholder
        Container(
          padding: const EdgeInsets.all(AppTheme.sp20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.borderGray200,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 40, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.sp8),
              const Text(
                'Add Photos / Videos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Image picker available in Phase 3',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepLocation extends StatelessWidget {
  final TextEditingController controller;
  final bool useCurrentLocation;
  final void Function(bool) onToggle;

  const _StepLocation({
    required this.controller,
    required this.useCurrentLocation,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where is the issue?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.sp4),
        Text(
          'Accurate location helps the right team respond faster.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp20),
        // Toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(true),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.sp12),
                  decoration: BoxDecoration(
                    color: useCurrentLocation
                        ? AppTheme.primaryNavy.withValues(alpha: 0.08)
                        : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: useCurrentLocation
                          ? AppTheme.primaryNavy
                          : AppTheme.borderGray200,
                      width: useCurrentLocation ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.my_location_rounded,
                          color: useCurrentLocation
                              ? AppTheme.primaryNavy
                              : AppTheme.textTertiary),
                      const SizedBox(height: 4),
                      Text(
                        'Use GPS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: useCurrentLocation
                              ? AppTheme.primaryNavy
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.sp12),
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(false),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.sp12),
                  decoration: BoxDecoration(
                    color: !useCurrentLocation
                        ? AppTheme.primaryNavy.withValues(alpha: 0.08)
                        : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: !useCurrentLocation
                          ? AppTheme.primaryNavy
                          : AppTheme.borderGray200,
                      width: !useCurrentLocation ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.edit_location_alt_outlined,
                          color: !useCurrentLocation
                              ? AppTheme.primaryNavy
                              : AppTheme.textTertiary),
                      const SizedBox(height: 4),
                      Text(
                        'Enter Manually',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: !useCurrentLocation
                              ? AppTheme.primaryNavy
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp16),
        // Map placeholder
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppTheme.surfaceGray100,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderGray200),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined,
                    size: 40, color: AppTheme.textTertiary),
                const SizedBox(height: 8),
                Text(
                  'Interactive map — Phase 3',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.sp16),
        CivicAITextField(
          controller: controller,
          label: 'Location Description',
          hint: 'Landmark, street name, area…',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }
}

class _StepReview extends StatelessWidget {
  final ComplaintCategory? category;
  final ComplaintSeverity severity;
  final String title;
  final String description;
  final String location;

  const _StepReview({
    this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final catInfo = DemoData.categories.firstWhere(
      (c) => c.category == category,
      orElse: () => DemoData.categories.last,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Submit',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.sp4),
        Text(
          'Please confirm the details before submitting.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp20),
        // AI preview
        Container(
          padding: const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            color: AppTheme.tealAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
                color: AppTheme.tealAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.tealAccent, size: 20),
              const SizedBox(width: AppTheme.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Classification Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.tealAccent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${catInfo.icon} ${catInfo.label} → Roads & Infrastructure Dept. (Demo)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sp16),
        _ReviewItem(
            label: 'Category', value: '${catInfo.icon} ${catInfo.label}'),
        _ReviewItem(
            label: 'Severity',
            value: severity.name.toUpperCase()),
        _ReviewItem(
            label: 'Title',
            value: title.isEmpty ? '(not entered)' : title),
        _ReviewItem(
            label: 'Description',
            value: description.isEmpty ? '(not entered)' : description),
        _ReviewItem(label: 'Location', value: location),
        const SizedBox(height: AppTheme.sp16),
        Container(
          padding: const EdgeInsets.all(AppTheme.sp12),
          decoration: BoxDecoration(
            color: AppTheme.warningAmber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
                color: AppTheme.warningAmber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppTheme.warningAmber),
              const SizedBox(width: AppTheme.sp8),
              Expanded(
                child: Text(
                  'DEMO: Submission simulates a 1.8 s API call. No real data is stored.',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.warningAmber),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sp12),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.sp12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderGray200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SuccessDetail(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int step;
  final int totalSteps;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.step,
    required this.totalSteps,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.sp20,
        AppTheme.sp12,
        AppTheme.sp20,
        MediaQuery.paddingOf(context).bottom + AppTheme.sp12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(top: BorderSide(color: AppTheme.borderGray200)),
      ),
      child: Row(
        children: [
          if (step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
            ),
          if (step > 0) const SizedBox(width: AppTheme.sp12),
          Expanded(
            flex: step == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onNext,
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      step < totalSteps - 1 ? 'Next' : 'Submit Complaint',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
