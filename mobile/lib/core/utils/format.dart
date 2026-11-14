import 'package:intl/intl.dart';

String formatDate(DateTime? value) =>
    value == null ? '—' : DateFormat('d MMM yyyy').format(value);

String formatDateTime(DateTime? value) =>
    value == null ? '—' : DateFormat('d MMM, h:mm a').format(value);

String formatTime(DateTime? value) =>
    value == null ? '—' : DateFormat('h:mm a').format(value);

String relativeTime(DateTime? value) {
  if (value == null) return '';
  final diff = DateTime.now().difference(value);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(value);
}

String formatHours(double hours) {
  if (hours <= 0) return '—';
  if (hours < 24) return '${hours.toStringAsFixed(hours < 10 ? 1 : 0)}h';
  final days = hours / 24;
  return '${days.toStringAsFixed(days < 10 ? 1 : 0)}d';
}

String dueLabel(DateTime dueAt, {bool isOpen = true}) {
  if (!isOpen) return 'Closed';
  final diff = dueAt.difference(DateTime.now());
  final overdue = diff.isNegative;
  final minutes = diff.inMinutes.abs();
  final text = minutes < 60
      ? '${minutes}m'
      : minutes < 1440
          ? '${diff.inHours.abs()}h'
          : '${diff.inDays.abs()}d';
  return overdue ? 'Overdue $text' : '$text left';
}

/// "2d left" / "Overdue 10h" split so the UI can colour only the overrun.
({String value, bool overdue}) dueParts(DateTime dueAt) {
  final diff = dueAt.difference(DateTime.now());
  final overdue = diff.isNegative;
  final minutes = diff.inMinutes.abs();
  final value = minutes < 60
      ? '${minutes}m'
      : minutes < 1440
          ? '${diff.inHours.abs()}h'
          : '${diff.inDays.abs()}d';
  return (value: value, overdue: overdue);
}
