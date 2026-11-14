import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();

  int? _departmentId;
  int? _categoryId;
  String? _ward;
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo must be smaller than 8 MB.')),
          );
        }
        return;
      }
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the photo picker: $error')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departmentId == null || _categoryId == null || _ward == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select a department, category and ward.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final api = ref.read(apiProvider);
    try {
      final created = await api.createComplaint(
        departmentId: _departmentId!,
        categoryId: _categoryId!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        ward: _ward!,
        address: _address.text.trim(),
        landmark: _landmark.text.trim(),
      );

      if (_photo != null && _photoBytes != null) {
        try {
          await api.uploadAttachment(
            created.id,
            fileName: _photo!.name,
            bytes: _photoBytes!,
            mimeType: _photo!.mimeType ?? 'image/jpeg',
          );
        } catch (_) {
          // The complaint is filed; evidence can be attached later from the
          // web console by an officer.
        }
      }

      ref.invalidate(complaintsProvider);
      ref.invalidate(analyticsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(lookupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an issue'),
      ),
      body: lookups.when(
        loading: () => const LoadingPane(),
        error: (error, _) => ListView(
          children: [
            ErrorPane(
              message: error.toString(),
              onRetry: () => ref.invalidate(lookupsProvider),
            ),
          ],
        ),
        data: (data) {
          final categories = _departmentId == null
              ? const <ComplaintCategory>[]
              : data.categoriesFor(_departmentId!);
          final selectedCategory = data.categoryById(_categoryId);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              children: [
                Text(
                  'Give the municipality enough detail to route and resolve the issue.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                CivicField(
                  label: 'Complaint title',
                  required: true,
                  child: TextFormField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Streetlight not working near 4th cross',
                      counterText: '',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 5)
                            ? 'Use at least 5 characters'
                            : null,
                  ),
                ),
                const SizedBox(height: 14),
                CivicField(
                  label: 'What is happening?',
                  required: true,
                  child: TextFormField(
                    controller: _description,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe the problem, how long it has existed, and any safety risk…',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 10)
                            ? 'Add at least 10 characters'
                            : null,
                  ),
                ),
                const SizedBox(height: 14),
                CivicField(
                  label: 'Department',
                  required: true,
                  child: DropdownButtonFormField<int>(
                    initialValue: _departmentId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(hintText: 'Select department'),
                    items: data.departments
                        .map((department) => DropdownMenuItem(
                              value: department.id,
                              child: Text(
                                department.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      _departmentId = value;
                      _categoryId = null;
                    }),
                    validator: (value) =>
                        value == null ? 'Select a department' : null,
                  ),
                ),
                const SizedBox(height: 14),
                CivicField(
                  label: 'Category',
                  required: true,
                  hint: selectedCategory == null
                      ? null
                      : 'SLA target: ${selectedCategory.slaHours} hours',
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_departmentId),
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: _departmentId == null
                          ? 'Select a department first'
                          : 'Select category',
                    ),
                    items: categories
                        .map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: _departmentId == null
                        ? null
                        : (value) => setState(() => _categoryId = value),
                    validator: (value) =>
                        value == null ? 'Select a category' : null,
                  ),
                ),
                const SizedBox(height: 14),
                CivicField(
                  label: 'Ward',
                  required: true,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ward,
                    isExpanded: true,
                    decoration: const InputDecoration(hintText: 'Select ward'),
                    items: kWards
                        .map((ward) => DropdownMenuItem(
                              value: ward,
                              child: Text(ward, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _ward = value),
                    validator: (value) =>
                        value == null ? 'Select the ward' : null,
                  ),
                ),
                const SizedBox(height: 14),
                CivicField(
                  label: 'Street address',
                  required: true,
                  child: TextFormField(
                    controller: _address,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Building, street, cross, area',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 5)
                            ? 'Add a street address'
                            : null,
                  ),
                ),
                const SizedBox(height: 14),
                CivicField(
                  label: 'Landmark',
                  hint: 'Optional nearby reference',
                  child: TextFormField(
                    controller: _landmark,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Opposite the ward office',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                CivicField(
                  label: 'Photo evidence',
                  hint: 'Optional · one image up to 8 MB',
                  child: _PhotoPicker(
                    bytes: _photoBytes,
                    name: _photo?.name,
                    onPick: _submitting ? null : _pickPhoto,
                    onClear: _submitting
                        ? null
                        : () => setState(() {
                              _photo = null;
                              _photoBytes = null;
                            }),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                        _submitting ? 'Filing complaint…' : 'Submit complaint'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You will receive a complaint reference and in-app updates as the status changes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.name,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? bytes;
  final String? name;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: AppColors.line,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  size: 26, color: AppColors.primary),
              const SizedBox(height: 6),
              const Text(
                'Add a photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'JPG or PNG, up to 8 MB',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Image.memory(
              bytes!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'Photo attached',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(bytes!.length / 1024).round()} KB',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove photo',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
