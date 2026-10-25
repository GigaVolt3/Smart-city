/// ⚠️  DEMO DATA — NOT connected to a real backend
///
/// All data in this file is fictional and used only for UI demonstration
/// during Phase 1. It will be replaced with real API calls in Phase 3.

enum ComplaintStatus {
  pending,
  assigned,
  inProgress,
  escalated,
  resolved,
  closed,
  rejected,
}

enum ComplaintCategory {
  pothole,
  garbage,
  streetlight,
  waterLeakage,
  brokenRoad,
  drainBlockage,
  other,
}

enum ComplaintSeverity { low, medium, high, critical }

class DemoComplaint {
  final String id;
  final String title;
  final String description;
  final ComplaintCategory category;
  final ComplaintSeverity severity;
  final ComplaintStatus status;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime? dueAt;
  final String? assignedDepartment;
  final String? assignedOfficer;
  final int escalationLevel;
  final double? aiConfidence;
  final List<DemoStatusEvent> timeline;

  const DemoComplaint({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.dueAt,
    this.assignedDepartment,
    this.assignedOfficer,
    this.escalationLevel = 0,
    this.aiConfidence,
    this.timeline = const [],
  });

  String get categoryLabel => switch (category) {
        ComplaintCategory.pothole => 'Pothole',
        ComplaintCategory.garbage => 'Garbage Accumulation',
        ComplaintCategory.streetlight => 'Broken Streetlight',
        ComplaintCategory.waterLeakage => 'Water Leakage',
        ComplaintCategory.brokenRoad => 'Damaged Road',
        ComplaintCategory.drainBlockage => 'Blocked Drain',
        ComplaintCategory.other => 'Other',
      };

  String get severityLabel => switch (severity) {
        ComplaintSeverity.low => 'Low',
        ComplaintSeverity.medium => 'Medium',
        ComplaintSeverity.high => 'High',
        ComplaintSeverity.critical => 'Critical',
      };

  String get statusKey => switch (status) {
        ComplaintStatus.pending => 'pending',
        ComplaintStatus.assigned => 'assigned',
        ComplaintStatus.inProgress => 'in_progress',
        ComplaintStatus.escalated => 'escalated',
        ComplaintStatus.resolved => 'resolved',
        ComplaintStatus.closed => 'closed',
        ComplaintStatus.rejected => 'rejected',
      };
}

class DemoStatusEvent {
  final ComplaintStatus status;
  final DateTime timestamp;
  final String actor;
  final String? note;
  final bool isEscalation;

  const DemoStatusEvent({
    required this.status,
    required this.timestamp,
    required this.actor,
    this.note,
    this.isEscalation = false,
  });

  String get statusKey => switch (status) {
        ComplaintStatus.pending => 'pending',
        ComplaintStatus.assigned => 'assigned',
        ComplaintStatus.inProgress => 'in_progress',
        ComplaintStatus.escalated => 'escalated',
        ComplaintStatus.resolved => 'resolved',
        ComplaintStatus.closed => 'closed',
        ComplaintStatus.rejected => 'rejected',
      };
}

/// All demo data lives here — clearly labelled so it is never mistaken for live data.
class DemoData {
  DemoData._();

  static final complaints = <DemoComplaint>[
    DemoComplaint(
      id: 'CMP-2024-001',
      title: 'Large pothole on MG Road',
      description:
          'There is a very deep pothole near the junction of MG Road and Brigade Road. It is causing accidents for two-wheelers.',
      category: ComplaintCategory.pothole,
      severity: ComplaintSeverity.high,
      status: ComplaintStatus.escalated,
      location: 'MG Road, Near Brigade Junction, Bengaluru',
      latitude: 12.9716,
      longitude: 77.5946,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      dueAt: DateTime.now().subtract(const Duration(days: 3)),
      assignedDepartment: 'Roads & Infrastructure',
      assignedOfficer: 'Ramesh Kumar',
      escalationLevel: 1,
      aiConfidence: 0.94,
      timeline: [
        DemoStatusEvent(
          status: ComplaintStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(days: 8)),
          actor: 'Citizen (You)',
          note: 'Complaint submitted',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.assigned,
          timestamp: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
          actor: 'System (AI Auto-assign)',
          note: 'Assigned to Roads & Infrastructure dept.',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.inProgress,
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          actor: 'Ramesh Kumar',
          note: 'Site inspection scheduled',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.escalated,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          actor: 'System (Escalation Engine)',
          note: 'Response deadline exceeded. Escalated to Supervisor.',
          isEscalation: true,
        ),
      ],
    ),
    DemoComplaint(
      id: 'CMP-2024-002',
      title: 'Garbage pile at Indiranagar 12th Cross',
      description:
          'Garbage has been piling up for 5 days near the bus stop. The area smells and mosquito breeding is visible.',
      category: ComplaintCategory.garbage,
      severity: ComplaintSeverity.medium,
      status: ComplaintStatus.inProgress,
      location: '12th Cross, Indiranagar, Bengaluru',
      latitude: 12.9784,
      longitude: 77.6408,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      dueAt: DateTime.now().add(const Duration(days: 1)),
      assignedDepartment: 'Solid Waste Management',
      assignedOfficer: 'Priya Sharma',
      escalationLevel: 0,
      aiConfidence: 0.88,
      timeline: [
        DemoStatusEvent(
          status: ComplaintStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(days: 4)),
          actor: 'Citizen (You)',
          note: 'Complaint submitted',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.assigned,
          timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
          actor: 'System (AI Auto-assign)',
          note: 'Assigned to Solid Waste Management dept.',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.inProgress,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          actor: 'Priya Sharma',
          note: 'Cleaning truck dispatched',
        ),
      ],
    ),
    DemoComplaint(
      id: 'CMP-2024-003',
      title: 'Streetlight not working — Koramangala 5th Block',
      description:
          'The streetlight pole #KRM-45 has not been working for 3 days. The street is completely dark at night.',
      category: ComplaintCategory.streetlight,
      severity: ComplaintSeverity.low,
      status: ComplaintStatus.resolved,
      location: '5th Block, Koramangala, Bengaluru',
      latitude: 12.9352,
      longitude: 77.6245,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      dueAt: DateTime.now().subtract(const Duration(days: 6)),
      assignedDepartment: 'Electrical & Lighting',
      assignedOfficer: 'Suresh Naik',
      escalationLevel: 0,
      aiConfidence: 0.97,
      timeline: [
        DemoStatusEvent(
          status: ComplaintStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(days: 10)),
          actor: 'Citizen (You)',
          note: 'Complaint submitted',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.assigned,
          timestamp: DateTime.now().subtract(const Duration(days: 9, hours: 3)),
          actor: 'System (AI Auto-assign)',
          note: 'Assigned to Electrical dept.',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.inProgress,
          timestamp: DateTime.now().subtract(const Duration(days: 8)),
          actor: 'Suresh Naik',
          note: 'Repair team dispatched',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.resolved,
          timestamp: DateTime.now().subtract(const Duration(days: 6, hours: 5)),
          actor: 'Suresh Naik',
          note: 'Streetlight repaired and tested.',
        ),
      ],
    ),
    DemoComplaint(
      id: 'CMP-2024-004',
      title: 'Water pipeline burst — HSR Layout',
      description:
          'A water main has burst near the main road. Water is flooding the road and causing waterlogging.',
      category: ComplaintCategory.waterLeakage,
      severity: ComplaintSeverity.critical,
      status: ComplaintStatus.inProgress,
      location: 'Sector 1, HSR Layout, Bengaluru',
      latitude: 12.9116,
      longitude: 77.6474,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      dueAt: DateTime.now().add(const Duration(hours: 18)),
      assignedDepartment: 'Water & Sewerage',
      assignedOfficer: 'Abdul Rashid',
      escalationLevel: 0,
      aiConfidence: 0.91,
      timeline: [
        DemoStatusEvent(
          status: ComplaintStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          actor: 'Citizen (You)',
          note: 'Complaint submitted with photo evidence',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.assigned,
          timestamp: DateTime.now().subtract(const Duration(hours: 5, minutes: 30)),
          actor: 'System (AI Auto-assign)',
          note: 'Marked CRITICAL. Assigned to Water & Sewerage dept.',
        ),
        DemoStatusEvent(
          status: ComplaintStatus.inProgress,
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          actor: 'Abdul Rashid',
          note: 'Emergency repair team en route',
        ),
      ],
    ),
    DemoComplaint(
      id: 'CMP-2024-005',
      title: 'Blocked drain flooding during rain',
      description:
          'The main drain near our colony is completely blocked. During any rainfall the street floods knee-deep.',
      category: ComplaintCategory.drainBlockage,
      severity: ComplaintSeverity.high,
      status: ComplaintStatus.pending,
      location: 'Rajajinagar 2nd Stage, Bengaluru',
      latitude: 12.9916,
      longitude: 77.5559,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      dueAt: DateTime.now().add(const Duration(days: 3)),
      assignedDepartment: null,
      assignedOfficer: null,
      escalationLevel: 0,
      aiConfidence: 0.85,
      timeline: [
        DemoStatusEvent(
          status: ComplaintStatus.pending,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          actor: 'Citizen (You)',
          note: 'Complaint submitted. Awaiting department assignment.',
        ),
      ],
    ),
  ];

  static final categories = <({ComplaintCategory category, String label, String icon, String description})>[
    (category: ComplaintCategory.pothole, label: 'Pothole', icon: '🕳️', description: 'Road potholes & surface damage'),
    (category: ComplaintCategory.garbage, label: 'Garbage', icon: '🗑️', description: 'Waste collection & dumping'),
    (category: ComplaintCategory.streetlight, label: 'Streetlight', icon: '💡', description: 'Non-functional street lights'),
    (category: ComplaintCategory.waterLeakage, label: 'Water Leak', icon: '💧', description: 'Water main leaks & bursts'),
    (category: ComplaintCategory.brokenRoad, label: 'Broken Road', icon: '🛣️', description: 'Road damage & cracks'),
    (category: ComplaintCategory.drainBlockage, label: 'Drain', icon: '🌊', description: 'Blocked & overflowing drains'),
    (category: ComplaintCategory.other, label: 'Other', icon: '📋', description: 'Other civic issues'),
  ];

  static const demoUser = (
    name: 'Roshan Khan',
    phone: '+91 98765 43210',
    email: 'roshan@example.com',
    ward: 'Ward 42, Bengaluru North',
  );

  static final stats = (
    total: 5,
    pending: 1,
    inProgress: 2,
    escalated: 1,
    resolved: 1,
  );
}
