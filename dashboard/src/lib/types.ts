export type Role = "citizen" | "officer" | "supervisor" | "admin";

export type ComplaintStatus =
  | "submitted"
  | "assigned"
  | "in_progress"
  | "escalated"
  | "resolved"
  | "rejected";

export type Priority = "low" | "medium" | "high" | "critical";

export interface User {
  id: number;
  email: string;
  full_name: string;
  phone_number?: string | null;
  ward?: string | null;
  role: Role;
  department_id?: number | null;
  is_active: boolean;
  created_at: string;
}

export interface Department {
  id: number;
  name: string;
  code: string;
  description?: string | null;
  contact_email?: string | null;
  contact_phone?: string | null;
  created_at: string;
}

export interface Category {
  id: number;
  department_id: number;
  name: string;
  code: string;
  description?: string | null;
  sla_hours: number;
  priority_default: Priority;
  is_active: boolean;
  created_at: string;
}

export interface Complaint {
  id: number;
  complaint_number: string;
  citizen_id: number;
  assigned_officer_id?: number | null;
  department_id: number;
  category_id: number;
  title: string;
  description: string;
  ward: string;
  address: string;
  landmark?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  status: ComplaintStatus;
  priority: Priority;
  escalation_level: number;
  due_at: string;
  resolved_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface Attachment {
  id: number;
  file_name: string;
  file_path: string;
  file_size: number;
  mime_type: string;
  uploaded_at: string;
}

export interface StatusHistoryEntry {
  id: number;
  complaint_id: number;
  previous_status?: string | null;
  new_status: string;
  changed_by_id?: number | null;
  comments?: string | null;
  created_at: string;
}

export interface EscalationEvent {
  id: number;
  complaint_id: number;
  from_level: number;
  to_level: number;
  reason: string;
  escalated_to_id?: number | null;
  created_at: string;
  complaint_number?: string | null;
  complaint_title?: string | null;
  department?: string | null;
  escalated_to_name?: string | null;
}

export interface ComplaintDetail extends Complaint {
  citizen?: User | null;
  assigned_officer?: User | null;
  department?: Department | null;
  category?: Category | null;
  attachments: Attachment[];
  status_history: StatusHistoryEntry[];
  escalation_events: EscalationEvent[];
}

export interface ComplaintPage {
  items: Complaint[];
  total: number;
  skip: number;
  limit: number;
}

export interface NotificationItem {
  id: number;
  user_id: number;
  complaint_id?: number | null;
  notification_type: string;
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
}

export interface NotificationList {
  items: NotificationItem[];
  total: number;
  unread_count: number;
}

export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  user: User;
}

export interface Kpis {
  total: number;
  open: number;
  resolved: number;
  rejected: number;
  escalated: number;
  critical_open: number;
  sla_breached: number;
  new_in_period: number;
  resolved_in_period: number;
  resolution_rate: number;
  sla_compliance_rate: number;
  avg_resolution_hours: number;
}

export interface CountPoint {
  status?: ComplaintStatus;
  priority?: Priority;
  count: number;
}

export interface TrendPoint {
  date: string;
  submitted: number;
  resolved: number;
}

export interface DepartmentPerformance {
  id: number;
  name: string;
  code: string;
  total: number;
  open: number;
  resolved: number;
  escalated: number;
  breached: number;
  sla_compliance_rate: number;
  avg_resolution_hours: number;
}

export interface CategoryCount {
  id: number;
  name: string;
  department?: string | null;
  count: number;
}

export interface WardCount {
  ward: string;
  total: number;
  open: number;
  breached: number;
}

export interface SlaSummary {
  on_track: number;
  at_risk: number;
  breached: number;
  compliance_rate: number;
}

export interface ActivityItem {
  id: number;
  complaint_id: number;
  complaint_number: string;
  title: string;
  previous_status?: string | null;
  new_status: string;
  comments?: string | null;
  actor: string;
  created_at: string;
}

export interface MapPoint {
  id: number;
  complaint_number: string;
  title: string;
  status: ComplaintStatus;
  priority: Priority;
  latitude: number;
  longitude: number;
  ward: string;
  category: string;
}

export interface AnalyticsOverview {
  role: Role;
  days: number;
  kpis: Kpis;
  status_breakdown: Array<{ status: ComplaintStatus; count: number }>;
  priority_breakdown: Array<{ priority: Priority; count: number }>;
  trend: TrendPoint[];
  departments: DepartmentPerformance[];
  categories: CategoryCount[];
  wards: WardCount[];
  sla: SlaSummary;
  recent_activity: ActivityItem[];
  map_points: MapPoint[];
  my: { assigned: number; filed: number; unread_notifications: number };
}

export interface ClassificationResult {
  category_id?: number | null;
  category_code?: string | null;
  category_name?: string | null;
  department_id?: number | null;
  department_code?: string | null;
  department_name?: string | null;
  confidence: number;
  suggested_priority: string;
  matched_keywords: string[];
  candidates: Array<{
    category_id: number;
    category_code: string;
    category_name: string;
    department_id: number;
    department_name?: string | null;
    confidence: number;
  }>;
}

export interface DuplicateMatch {
  complaint_id: number;
  complaint_number: string;
  title: string;
  status: string;
  ward?: string | null;
  distance_meters?: number | null;
  text_similarity: number;
  geo_similarity?: number | null;
  overall_similarity: number;
  created_at: string;
}

export interface DuplicateResult {
  is_duplicate: boolean;
  confidence: number;
  primary_complaint_id?: number | null;
  matches: DuplicateMatch[];
  total_candidates_analyzed: number;
}

export interface PriorityScore {
  priority_score: number;
  priority_level: string;
  recommended_sla_hours: number;
  factors: string[];
  score_breakdown: Record<string, number>;
}

export interface HotspotCluster {
  hotspot_id: string;
  centroid: { latitude: number; longitude: number };
  radius_meters: number;
  total_complaints: number;
  open_complaints: number;
  resolved_complaints: number;
  unresolved_rate: number;
  recurrence_score: number;
  severity_tier: string;
  predominant_category: Record<string, unknown>;
  predominant_department: Record<string, unknown>;
  affected_wards: string[];
  first_reported_at: string;
  last_reported_at: string;
  avg_recurrence_interval_days: number;
  sample_complaints: Array<Record<string, unknown>>;
}

export interface HotspotsResult {
  total_complaints_analyzed: number;
  total_hotspots: number;
  hotspots: HotspotCluster[];
  geojson: Record<string, unknown>;
  summary: {
    most_critical_ward?: string | null;
    top_recurring_category?: string | null;
    avg_cluster_size: number;
  };
}

export interface ImageComparison {
  is_verified: boolean;
  verification_status: string;
  resolution_score: number;
  confidence: number;
  metrics: Record<string, number | string>;
  explanation: string;
}

export interface EscalationRule {
  id: number;
  department_id?: number | null;
  category_id?: number | null;
  escalation_level: number;
  trigger_hours: number;
  target_role: string;
  created_at: string;
}

export interface EscalationSummary {
  total_events: number;
  open_escalated: number;
  by_level: Record<string, number>;
  by_department: Array<{ department: string; count: number }>;
}

export interface AuditEvent {
  id: number;
  user_id?: number | null;
  user_name?: string | null;
  action: string;
  resource_type: string;
  resource_id?: string | null;
  details?: string | null;
  ip_address?: string | null;
  created_at: string;
}
