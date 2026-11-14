/// API data models for the CivicAI backend.
///
/// All dates arrive as ISO-8601 strings. The backend stores naive UTC
/// timestamps (SQLite), so [parseApiDate] appends `Z` when no offset is
/// present to avoid rendering times shifted by the device offset.
library;

DateTime? parseApiDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  return DateTime.tryParse(hasZone ? raw : '${raw}Z')?.toLocal();
}

String? _string(dynamic value) => value?.toString();

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.ward,
    this.departmentId,
    this.isActive = true,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final String? phoneNumber;
  final String? ward;
  final int? departmentId;
  final bool isActive;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? fullName : parts.first;
  }

  String get roleLabel => switch (role) {
        'admin' => 'Administrator',
        'supervisor' => 'Supervisor',
        'officer' => 'Field officer',
        _ => 'Citizen',
      };

  bool get isStaff => role == 'admin' || role == 'supervisor' || role == 'officer';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: _int(json['id']) ?? 0,
        email: _string(json['email']) ?? '',
        fullName: _string(json['full_name']) ?? 'Resident',
        role: _string(json['role']) ?? 'citizen',
        phoneNumber: _string(json['phone_number']),
        ward: _string(json['ward']),
        departmentId: _int(json['department_id']),
        isActive: json['is_active'] != false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'phone_number': phoneNumber,
        'ward': ward,
        'department_id': departmentId,
        'is_active': isActive,
      };
}

class Department {
  const Department({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.contactEmail,
    this.contactPhone,
  });

  final int id;
  final String name;
  final String code;
  final String? description;
  final String? contactEmail;
  final String? contactPhone;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: _int(json['id']) ?? 0,
        name: _string(json['name']) ?? '',
        code: _string(json['code']) ?? '',
        description: _string(json['description']),
        contactEmail: _string(json['contact_email']),
        contactPhone: _string(json['contact_phone']),
      );
}

class ComplaintCategory {
  const ComplaintCategory({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.code,
    required this.slaHours,
    required this.priorityDefault,
    this.description,
    this.isActive = true,
  });

  final int id;
  final int departmentId;
  final String name;
  final String code;
  final int slaHours;
  final String priorityDefault;
  final String? description;
  final bool isActive;

  factory ComplaintCategory.fromJson(Map<String, dynamic> json) =>
      ComplaintCategory(
        id: _int(json['id']) ?? 0,
        departmentId: _int(json['department_id']) ?? 0,
        name: _string(json['name']) ?? '',
        code: _string(json['code']) ?? '',
        slaHours: _int(json['sla_hours']) ?? 48,
        priorityDefault: _string(json['priority_default']) ?? 'medium',
        description: _string(json['description']),
        isActive: json['is_active'] != false,
      );
}

class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.fileSize,
    this.uploadedAt,
  });

  final int id;
  final String fileName;
  final String filePath;
  final String mimeType;
  final int fileSize;
  final DateTime? uploadedAt;

  bool get isImage => mimeType.startsWith('image/');

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: _int(json['id']) ?? 0,
        fileName: _string(json['file_name']) ?? 'Attachment',
        filePath: _string(json['file_path']) ?? '',
        mimeType: _string(json['mime_type']) ?? 'application/octet-stream',
        fileSize: _int(json['file_size']) ?? 0,
        uploadedAt: parseApiDate(_string(json['uploaded_at'])),
      );
}

class StatusEvent {
  const StatusEvent({
    required this.newStatus,
    this.previousStatus,
    this.comments,
    this.createdAt,
    this.changedById,
  });

  final String newStatus;
  final String? previousStatus;
  final String? comments;
  final DateTime? createdAt;
  final int? changedById;

  factory StatusEvent.fromJson(Map<String, dynamic> json) => StatusEvent(
        newStatus: _string(json['new_status']) ?? 'submitted',
        previousStatus: _string(json['previous_status']),
        comments: _string(json['comments']),
        createdAt: parseApiDate(_string(json['created_at'])),
        changedById: _int(json['changed_by_id']),
      );
}

class Complaint {
  const Complaint({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.ward,
    required this.address,
    required this.status,
    required this.priority,
    required this.departmentId,
    required this.categoryId,
    required this.createdAt,
    required this.dueAt,
    this.landmark,
    this.latitude,
    this.longitude,
    this.escalationLevel = 0,
    this.resolvedAt,
    this.citizenId,
    this.assignedOfficerId,
  });

  final int id;
  final String number;
  final String title;
  final String description;
  final String ward;
  final String address;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String status;
  final String priority;
  final int escalationLevel;
  final int departmentId;
  final int categoryId;
  final int? citizenId;
  final int? assignedOfficerId;
  final DateTime? createdAt;
  final DateTime dueAt;
  final DateTime? resolvedAt;

  bool get isOpen =>
      status != 'resolved' && status != 'rejected';

  bool get isOverdue =>
      isOpen && DateTime.now().isAfter(dueAt);

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final due = parseApiDate(_string(json['due_at'])) ?? DateTime.now();
    return Complaint(
      id: _int(json['id']) ?? 0,
      number: _string(json['complaint_number']) ?? '#',
      title: _string(json['title']) ?? 'Untitled complaint',
      description: _string(json['description']) ?? '',
      ward: _string(json['ward']) ?? '',
      address: _string(json['address']) ?? '',
      landmark: _string(json['landmark']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      status: _string(json['status']) ?? 'submitted',
      priority: _string(json['priority']) ?? 'medium',
      escalationLevel: _int(json['escalation_level']) ?? 0,
      departmentId: _int(json['department_id']) ?? 0,
      categoryId: _int(json['category_id']) ?? 0,
      citizenId: _int(json['citizen_id']),
      assignedOfficerId: _int(json['assigned_officer_id']),
      createdAt: parseApiDate(_string(json['created_at'])),
      dueAt: due,
      resolvedAt: parseApiDate(_string(json['resolved_at'])),
    );
  }
}

class ComplaintDetail extends Complaint {
  const ComplaintDetail({
    required super.id,
    required super.number,
    required super.title,
    required super.description,
    required super.ward,
    required super.address,
    required super.status,
    required super.priority,
    required super.departmentId,
    required super.categoryId,
    required super.createdAt,
    required super.dueAt,
    super.landmark,
    super.latitude,
    super.longitude,
    super.escalationLevel,
    super.resolvedAt,
    super.citizenId,
    super.assignedOfficerId,
    this.department,
    this.category,
    this.citizen,
    this.assignedOfficer,
    this.attachments = const [],
    this.statusHistory = const [],
  });

  final Department? department;
  final ComplaintCategory? category;
  final User? citizen;
  final User? assignedOfficer;
  final List<Attachment> attachments;
  final List<StatusEvent> statusHistory;

  factory ComplaintDetail.fromJson(Map<String, dynamic> json) {
    final base = Complaint.fromJson(json);
    return ComplaintDetail(
      id: base.id,
      number: base.number,
      title: base.title,
      description: base.description,
      ward: base.ward,
      address: base.address,
      landmark: base.landmark,
      latitude: base.latitude,
      longitude: base.longitude,
      status: base.status,
      priority: base.priority,
      escalationLevel: base.escalationLevel,
      departmentId: base.departmentId,
      categoryId: base.categoryId,
      citizenId: base.citizenId,
      assignedOfficerId: base.assignedOfficerId,
      createdAt: base.createdAt,
      dueAt: base.dueAt,
      resolvedAt: base.resolvedAt,
      department: json['department'] is Map<String, dynamic>
          ? Department.fromJson(json['department'] as Map<String, dynamic>)
          : null,
      category: json['category'] is Map<String, dynamic>
          ? ComplaintCategory.fromJson(
              json['category'] as Map<String, dynamic>,
            )
          : null,
      citizen: json['citizen'] is Map<String, dynamic>
          ? User.fromJson(json['citizen'] as Map<String, dynamic>)
          : null,
      assignedOfficer: json['assigned_officer'] is Map<String, dynamic>
          ? User.fromJson(json['assigned_officer'] as Map<String, dynamic>)
          : null,
      attachments: _list(json['attachments'])
          .whereType<Map<String, dynamic>>()
          .map(Attachment.fromJson)
          .toList(),
      statusHistory: _list(json['status_history'])
          .whereType<Map<String, dynamic>>()
          .map(StatusEvent.fromJson)
          .toList(),
    );
  }
}

class ComplaintPage {
  const ComplaintPage({
    required this.items,
    required this.total,
    this.skip = 0,
    this.limit = 20,
  });

  final List<Complaint> items;
  final int total;
  final int skip;
  final int limit;

  factory ComplaintPage.fromJson(Map<String, dynamic> json) => ComplaintPage(
        items: _list(json['items'])
            .whereType<Map<String, dynamic>>()
            .map(Complaint.fromJson)
            .toList(),
        total: _int(json['total']) ?? 0,
        skip: _int(json['skip']) ?? 0,
        limit: _int(json['limit']) ?? 20,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.complaintId,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final int? complaintId;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: _int(json['id']) ?? 0,
        title: _string(json['title']) ?? 'Update',
        message: _string(json['message']) ?? '',
        type: _string(json['notification_type']) ?? 'general',
        isRead: json['is_read'] == true,
        createdAt: parseApiDate(_string(json['created_at'])),
        complaintId: _int(json['complaint_id']),
      );
}

class NotificationFeed {
  const NotificationFeed({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int total;
  final int unreadCount;

  factory NotificationFeed.fromJson(Map<String, dynamic> json) =>
      NotificationFeed(
        items: _list(json['items'])
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList(),
        total: _int(json['total']) ?? 0,
        unreadCount: _int(json['unread_count']) ?? 0,
      );
}

class KpiSummary {
  const KpiSummary({
    required this.total,
    required this.open,
    required this.resolved,
    required this.escalated,
    required this.criticalOpen,
    required this.slaBreached,
    required this.resolutionRate,
    required this.slaComplianceRate,
    required this.avgResolutionHours,
  });

  final int total;
  final int open;
  final int resolved;
  final int escalated;
  final int criticalOpen;
  final int slaBreached;
  final double resolutionRate;
  final double slaComplianceRate;
  final double avgResolutionHours;

  factory KpiSummary.fromJson(Map<String, dynamic> json) => KpiSummary(
        total: _int(json['total']) ?? 0,
        open: _int(json['open']) ?? 0,
        resolved: _int(json['resolved']) ?? 0,
        escalated: _int(json['escalated']) ?? 0,
        criticalOpen: _int(json['critical_open']) ?? 0,
        slaBreached: _int(json['sla_breached']) ?? 0,
        resolutionRate: _double(json['resolution_rate']) ?? 0,
        slaComplianceRate: _double(json['sla_compliance_rate']) ?? 0,
        avgResolutionHours: _double(json['avg_resolution_hours']) ?? 0,
      );
}

class SlaSummary {
  const SlaSummary({
    required this.onTrack,
    required this.atRisk,
    required this.breached,
    required this.complianceRate,
  });

  final int onTrack;
  final int atRisk;
  final int breached;
  final double complianceRate;

  factory SlaSummary.fromJson(Map<String, dynamic> json) => SlaSummary(
        onTrack: _int(json['on_track']) ?? 0,
        atRisk: _int(json['at_risk']) ?? 0,
        breached: _int(json['breached']) ?? 0,
        complianceRate: _double(json['compliance_rate']) ?? 0,
      );
}

class CountRow {
  const CountRow({required this.label, required this.count, this.id});
  final String label;
  final int count;
  final int? id;

  factory CountRow.fromStatus(Map<String, dynamic> json) => CountRow(
        label: _string(json['status']) ?? '—',
        count: _int(json['count']) ?? 0,
      );

  factory CountRow.fromPriority(Map<String, dynamic> json) => CountRow(
        label: _string(json['priority']) ?? '—',
        count: _int(json['count']) ?? 0,
      );

  factory CountRow.fromCategory(Map<String, dynamic> json) => CountRow(
        id: _int(json['id']),
        label: _string(json['name']) ?? '—',
        count: _int(json['count']) ?? 0,
      );

  factory CountRow.fromWard(Map<String, dynamic> json) => CountRow(
        label: _string(json['ward']) ?? '—',
        count: _int(json['total']) ?? 0,
      );
}

class DepartmentPerformance {
  const DepartmentPerformance({
    required this.name,
    required this.code,
    required this.total,
    required this.open,
    required this.resolved,
    required this.escalated,
    required this.breached,
    required this.slaComplianceRate,
    required this.avgResolutionHours,
  });

  final String name;
  final String code;
  final int total;
  final int open;
  final int resolved;
  final int escalated;
  final int breached;
  final double slaComplianceRate;
  final double avgResolutionHours;

  factory DepartmentPerformance.fromJson(Map<String, dynamic> json) =>
      DepartmentPerformance(
        name: _string(json['name']) ?? '—',
        code: _string(json['code']) ?? '',
        total: _int(json['total']) ?? 0,
        open: _int(json['open']) ?? 0,
        resolved: _int(json['resolved']) ?? 0,
        escalated: _int(json['escalated']) ?? 0,
        breached: _int(json['breached']) ?? 0,
        slaComplianceRate: _double(json['sla_compliance_rate']) ?? 0,
        avgResolutionHours: _double(json['avg_resolution_hours']) ?? 0,
      );
}

class MapPoint {
  const MapPoint({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.ward,
    required this.category,
  });

  final int id;
  final String number;
  final String title;
  final String status;
  final String priority;
  final double latitude;
  final double longitude;
  final String ward;
  final String category;

  factory MapPoint.fromJson(Map<String, dynamic> json) => MapPoint(
        id: _int(json['id']) ?? 0,
        number: _string(json['complaint_number']) ?? '',
        title: _string(json['title']) ?? '',
        status: _string(json['status']) ?? 'submitted',
        priority: _string(json['priority']) ?? 'medium',
        latitude: _double(json['latitude']) ?? 0,
        longitude: _double(json['longitude']) ?? 0,
        ward: _string(json['ward']) ?? '',
        category: _string(json['category']) ?? '',
      );
}

class ActivityItem {
  const ActivityItem({
    required this.complaintId,
    required this.complaintNumber,
    required this.title,
    required this.newStatus,
    required this.actor,
    this.comments,
    this.createdAt,
  });

  final int complaintId;
  final String complaintNumber;
  final String title;
  final String newStatus;
  final String actor;
  final String? comments;
  final DateTime? createdAt;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        complaintId: _int(json['complaint_id']) ?? 0,
        complaintNumber: _string(json['complaint_number']) ?? '',
        title: _string(json['title']) ?? '',
        newStatus: _string(json['new_status']) ?? '',
        actor: _string(json['actor']) ?? 'System',
        comments: _string(json['comments']),
        createdAt: parseApiDate(_string(json['created_at'])),
      );
}

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.role,
    required this.days,
    required this.kpis,
    required this.sla,
    required this.statusBreakdown,
    required this.priorityBreakdown,
    required this.departments,
    required this.categories,
    required this.wards,
    required this.mapPoints,
    required this.recentActivity,
  });

  final String role;
  final int days;
  final KpiSummary kpis;
  final SlaSummary sla;
  final List<CountRow> statusBreakdown;
  final List<CountRow> priorityBreakdown;
  final List<DepartmentPerformance> departments;
  final List<CountRow> categories;
  final List<CountRow> wards;
  final List<MapPoint> mapPoints;
  final List<ActivityItem> recentActivity;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) =>
      AnalyticsOverview(
        role: _string(json['role']) ?? 'citizen',
        days: _int(json['days']) ?? 30,
        kpis: KpiSummary.fromJson(
          (json['kpis'] as Map<String, dynamic>?) ?? const {},
        ),
        sla: SlaSummary.fromJson(
          (json['sla'] as Map<String, dynamic>?) ?? const {},
        ),
        statusBreakdown: _list(json['status_breakdown'])
            .whereType<Map<String, dynamic>>()
            .map(CountRow.fromStatus)
            .toList(),
        priorityBreakdown: _list(json['priority_breakdown'])
            .whereType<Map<String, dynamic>>()
            .map(CountRow.fromPriority)
            .toList(),
        departments: _list(json['departments'])
            .whereType<Map<String, dynamic>>()
            .map(DepartmentPerformance.fromJson)
            .toList(),
        categories: _list(json['categories'])
            .whereType<Map<String, dynamic>>()
            .map(CountRow.fromCategory)
            .toList(),
        wards: _list(json['wards'])
            .whereType<Map<String, dynamic>>()
            .map(CountRow.fromWard)
            .toList(),
        mapPoints: _list(json['map_points'])
            .whereType<Map<String, dynamic>>()
            .map(MapPoint.fromJson)
            .toList(),
        recentActivity: _list(json['recent_activity'])
            .whereType<Map<String, dynamic>>()
            .map(ActivityItem.fromJson)
            .toList(),
      );
}

class Lookups {
  const Lookups({required this.departments, required this.categories});

  final List<Department> departments;
  final List<ComplaintCategory> categories;

  List<ComplaintCategory> categoriesFor(int departmentId) => categories
      .where((c) => c.departmentId == departmentId && c.isActive)
      .toList();

  Department? departmentById(int? id) {
    if (id == null) return null;
    for (final department in departments) {
      if (department.id == id) return department;
    }
    return null;
  }

  ComplaintCategory? categoryById(int? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

const kStatusLabels = <String, String>{
  'submitted': 'Submitted',
  'assigned': 'Assigned',
  'in_progress': 'In progress',
  'escalated': 'Escalated',
  'resolved': 'Resolved',
  'rejected': 'Rejected',
};

const kPriorityLabels = <String, String>{
  'low': 'Low',
  'medium': 'Medium',
  'high': 'High',
  'critical': 'Critical',
};

const kWards = <String>[
  'Ward 1 (Malleshwaram)',
  'Ward 3 (Rajajinagar)',
  'Ward 5 (Jayanagar)',
  'Ward 8 (Koramangala)',
  'Ward 9 (BTM Layout)',
  'Ward 12 (Indiranagar)',
  'Ward 15 (Domlur)',
  'Ward 18 (Whitefield)',
  'Ward 22 (HSR Layout)',
  'Ward 25 (Jayanagar East)',
];

class Hotspot {
  const Hotspot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.totalComplaints,
    required this.severityTier,
    required this.category,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int totalComplaints;
  final String severityTier;
  final String category;

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    final centroid = json['centroid'];
    final category = json['predominant_category'];
    return Hotspot(
      id: json['hotspot_id']?.toString() ?? '',
      latitude: centroid is Map ? _double(centroid['latitude']) ?? 0 : 0,
      longitude: centroid is Map ? _double(centroid['longitude']) ?? 0 : 0,
      radiusMeters: _double(json['radius_meters']) ?? 0,
      totalComplaints: _int(json['total_complaints']) ?? 0,
      severityTier: json['severity_tier']?.toString() ?? 'medium',
      category: category is Map
          ? category['name']?.toString() ?? 'Recurring issue'
          : 'Recurring issue',
    );
  }
}

class HotspotFeed {
  const HotspotFeed({required this.hotspots, required this.analysed});

  final List<Hotspot> hotspots;
  final int analysed;

  factory HotspotFeed.fromJson(Map<String, dynamic> json) => HotspotFeed(
        hotspots: _list(json['hotspots'])
            .whereType<Map<String, dynamic>>()
            .map(Hotspot.fromJson)
            .toList(),
        analysed: _int(json['total_complaints_analyzed']) ?? 0,
      );
}
