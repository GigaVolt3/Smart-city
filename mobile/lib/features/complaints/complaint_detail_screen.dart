import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';

class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final int complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(complaintDetailProvider(complaintId));
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(complaintDetailProvider(complaintId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: detail.when(
        loading: () => const LoadingPane(),
        error: (error, _) => ListView(
          children: [
            ErrorPane(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(complaintDetailProvider(complaintId)),
            ),
          ],
        ),
        data: (complaint) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(complaintDetailProvider(complaintId));
            await ref.read(complaintDetailProvider(complaintId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              _Header(complaint: complaint),
              const SizedBox(height: 14),
              _SlaCard(complaint: complaint),
              const SizedBox(height: 12),
              _DetailsCard(complaint: complaint),
              if (complaint.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                _EvidenceCard(complaint: complaint),
              ],
              const SizedBox(height: 12),
              _TimelineCard(complaint: complaint),
              if (complaint.escalationLevel > 0) ...[
                const SizedBox(height: 12),
                _EscalationCard(complaint: complaint),
              ],
              if (auth.user?.isStaff == true) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openStatusSheet(context, ref, complaint),
                  icon: const Icon(Icons.edit_note_rounded, size: 19),
                  label: const Text('Update status'),
                ),
              ],
              if (complaint.latitude != null && complaint.longitude != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${complaint.latitude},${complaint.longitude}',
                    );
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open location in maps'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStatusSheet(
    BuildContext context,
    WidgetRef ref,
    ComplaintDetail complaint,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _StatusSheet(complaint: complaint),
    );
    if (updated == true) {
      ref.invalidate(complaintDetailProvider(complaintId));
      ref.invalidate(complaintsProvider);
      ref.invalidate(analyticsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Status updated and citizen notified.')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.complaint});

  final ComplaintDetail complaint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                complaint.number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppColors.ink3,
                ),
              ),
            ),
            StatusPill(complaint.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          complaint.title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontSize: 23, height: 1.25),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PriorityPill(complaint.priority),
            if (complaint.department != null)
              _MetaChip(
                icon: Icons.account_balance_outlined,
                label: complaint.department!.name,
              ),
            if (complaint.category != null)
              _MetaChip(
                icon: Icons.category_outlined,
                label: complaint.category!.name,
              ),
            _MetaChip(
              icon: Icons.location_on_outlined,
              label: complaint.ward,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.ink3),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.ink3),
        ),
      ],
    );
  }
}

class _SlaCard extends StatelessWidget {
  const _SlaCard({required this.complaint});

  final ComplaintDetail complaint;

  @override
  Widget build(BuildContext context) {
    final resolved = complaint.status == 'resolved';
    final due = dueParts(complaint.dueAt);
    final breached = due.overdue && !resolved;
    final created = complaint.createdAt;
    final total = created == null
        ? 0
        : complaint.dueAt.difference(created).inMilliseconds;
    final elapsed =
        created == null ? 0 : DateTime.now().difference(created).inMilliseconds;
    final progress = resolved
        ? 1.0
        : (total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0));

    return CivicCard(
      color: breached ? AppColors.dangerSoft : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                resolved
                    ? Icons.verified_outlined
                    : breached
                        ? Icons.warning_amber_rounded
                        : Icons.timer_outlined,
                size: 19,
                color: resolved
                    ? AppColors.success
                    : breached
                        ? AppColors.danger
                        : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                resolved
                    ? 'Resolved'
                    : breached
                        ? 'Resolution deadline breached'
                        : 'Resolution deadline',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: breached ? AppColors.danger : AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                resolved
                    ? formatDate(complaint.resolvedAt)
                    : '${due.overdue ? 'Overdue ' : ''}${due.value}${due.overdue ? '' : ' left'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: resolved
                      ? AppColors.success
                      : breached
                          ? AppColors.danger
                          : AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white,
              color: resolved
                  ? AppColors.success
                  : breached
                      ? AppColors.danger
                      : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filed ${formatDate(complaint.createdAt)} · due ${formatDateTime(complaint.dueAt)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.complaint});

  final ComplaintDetail complaint;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Complaint details',
            subtitle: 'Citizen-submitted report',
          ),
          const SizedBox(height: 12),
          Text(
            complaint.description,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.ink2,
            ),
          ),
          const Divider(height: 26),
          InfoRow(label: 'Address', value: complaint.address),
          if (complaint.landmark != null && complaint.landmark!.isNotEmpty)
            InfoRow(label: 'Landmark', value: complaint.landmark!),
          InfoRow(label: 'Ward', value: complaint.ward),
          InfoRow(
            label: 'Filed on',
            value: formatDateTime(complaint.createdAt),
          ),
          InfoRow(
            label: 'Officer',
            value: complaint.assignedOfficer?.fullName ?? 'Awaiting assignment',
          ),
          InfoRow(
            label: 'Citizen',
            value: complaint.citizen?.fullName ?? '—',
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends ConsumerWidget {
  const _EvidenceCard({required this.complaint});

  final ComplaintDetail complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final attachments = complaint.attachments;
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Evidence',
            subtitle:
                '${attachments.length} file${attachments.length == 1 ? '' : 's'} attached',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                if (!attachment.isImage) {
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 26, color: AppColors.ink3),
                        const SizedBox(height: 6),
                        Text(
                          attachment.fileName,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Image.network(
                    api.fileUrl(attachment.filePath),
                    width: 190,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 190,
                      height: 150,
                      color: AppColors.canvas,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.ink3),
                      ),
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

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.complaint});

  final ComplaintDetail complaint;

  @override
  Widget build(BuildContext context) {
    final events = complaint.statusHistory;
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Resolution timeline',
            subtitle:
                '${events.length} status event${events.length == 1 ? '' : 's'} recorded',
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Text(
              'No status updates recorded yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (var i = 0; i < events.length; i++)
              _TimelineTile(
                event: events[i],
                isLast: i == events.length - 1,
              ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, required this.isLast});

  final StatusEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kStatusLabels[event.newStatus] ?? event.newStatus,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        relativeTime(event.createdAt),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.ink3),
                      ),
                    ],
                  ),
                  if (event.comments != null &&
                      event.comments!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.comments!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  const _EscalationCard({required this.complaint});

  final ComplaintDetail complaint;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      color: AppColors.dangerSoft,
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded,
              size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escalated to level ${complaint.escalationLevel}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'The SLA breach moved this case up the accountability chain.',
                  style: TextStyle(fontSize: 12, color: AppColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSheet extends ConsumerStatefulWidget {
  const _StatusSheet({required this.complaint});

  final ComplaintDetail complaint;

  @override
  ConsumerState<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<_StatusSheet> {
  late String _status = widget.complaint.status;
  final _comments = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).updateStatus(
            widget.complaint.id,
            status: _status,
            comments: _comments.text.trim(),
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Update complaint',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            widget.complaint.number,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          CivicField(
            label: 'New status',
            required: true,
            child: DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              items: kStatusLabels.entries
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
          ),
          const SizedBox(height: 14),
          CivicField(
            label: 'Note for the citizen',
            hint: 'Visible on the citizen timeline',
            child: TextField(
              controller: _comments,
              maxLines: 3,
              minLines: 2,
              decoration:
                  const InputDecoration(hintText: 'Describe the action taken…'),
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
                  : const Text('Save update'),
            ),
          ),
        ],
      ),
    );
  }
}
