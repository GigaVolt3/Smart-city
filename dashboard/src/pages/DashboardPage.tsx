import { useQueryClient, useMutation } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import {
  Activity,
  ArrowRight,
  CalendarClock,
  CheckCircle2,
  Clock3,
  MapPin,
  Plus,
  RefreshCw,
  ShieldAlert,
  Siren,
  TriangleAlert,
} from "lucide-react";
import {
  PageHeader,
  Button,
  Card,
  PageSkeleton,
  ErrorState,
  EmptyState,
  StatusBadge,
  PriorityBadge,
  SectionCard,
} from "../components/ui/primitives";
import { StatCard } from "../components/dashboard/StatCard";
import { VolumeChart, StatusDonut, SlaRing } from "../components/charts/Charts";
import { ComplaintMap } from "../components/maps/ComplaintMap";
import { useAnalytics, useComplaints } from "../hooks/queries";
import type { ComplaintStatus } from "../lib/types";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { api } from "../lib/api";
import {
  cn,
  formatDate,
  formatHours,
  priorityMeta,
  relativeTime,
  slaState,
  statusMeta,
} from "../lib/utils";

export function DashboardPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { notify } = useToast();
  const analytics = useAnalytics(30);
  const attention = useComplaints({ overdue: true, limit: 5 }, Boolean(user));

  const sweep = useMutation({
    mutationFn: () => api.post<{ escalated: number }>("/escalations/run"),
    onSuccess: (result) => {
      notify(
        result.escalated > 0
          ? `${result.escalated} complaint${result.escalated === 1 ? "" : "s"} escalated`
          : "No complaints are due for escalation",
        result.escalated > 0 ? "success" : "info",
      );
      queryClient.invalidateQueries();
    },
    onError: () => notify("Could not run the escalation sweep", "error"),
  });

  if (!user) return null;

  if (analytics.isLoading) return <PageSkeleton />;
  if (analytics.error || !analytics.data) {
    return (
      <div className="page">
        <ErrorState
          message={analytics.error instanceof Error ? analytics.error.message : undefined}
          onRetry={() => analytics.refetch()}
        />
      </div>
    );
  }

  const data = analytics.data;
  const kpis = data.kpis;
  const isStaff = user.role !== "citizen";
  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";
  const firstName = user.full_name.split(" ")[0];

  const statusData = data.status_breakdown
    .filter((entry) => entry.count > 0)
    .map((entry) => ({
      name: statusMeta[entry.status]?.label ?? entry.status,
      value: entry.count,
      color: statusMeta[entry.status]?.dot ?? "#94a3b8",
    }));

  const priorityMax = Math.max(1, ...data.priority_breakdown.map((entry) => entry.count));

  return (
    <div className="page">
      <PageHeader
        eyebrow={`${isStaff ? "Operations centre" : "Citizen portal"} · ${new Date().toLocaleDateString("en-IN", { weekday: "long", day: "numeric", month: "long" })}`}
        title={`${greeting}, ${firstName}`}
        description={
          isStaff
            ? `Live status across ${data.departments.length} departments. ${kpis.open} open cases, ${kpis.sla_breached} past SLA.`
            : `You have ${kpis.open} open complaint${kpis.open === 1 ? "" : "s"} and ${data.my.unread_notifications} unread update${data.my.unread_notifications === 1 ? "" : "s"}.`
        }
        actions={
          <>
            <Button
              variant="outline"
              size="sm"
              icon={<RefreshCw size={15} className={cn(analytics.isFetching && "spin")} />}
              onClick={() => analytics.refetch()}
            >
              Refresh
            </Button>
            {isStaff && (
              <Button
                variant="secondary"
                size="sm"
                icon={<Siren size={15} />}
                loading={sweep.isPending}
                onClick={() => sweep.mutate()}
              >
                Run SLA sweep
              </Button>
            )}
            <Button
              size="sm"
              icon={<Plus size={15} />}
              onClick={() => navigate("/complaints/new")}
            >
              Report issue
            </Button>
          </>
        }
      />

      {kpis.sla_breached > 0 && (
        <div className="alert alert--warning dashboard-alert">
          <ShieldAlert size={18} />
          <div>
            <strong>{kpis.sla_breached} complaints are past their resolution deadline.</strong>
            <span>
              {kpis.critical_open} critical open cases · {data.sla.at_risk} due within 24 hours
            </span>
          </div>
          <Button variant="ghost" size="sm" onClick={() => navigate("/complaints?overdue=true")}>
            Review queue <ArrowRight size={15} />
          </Button>
        </div>
      )}

      <div className="kpi-grid">
        <StatCard
          label="Open cases"
          value={kpis.open}
          hint={`${kpis.critical_open} critical · ${kpis.escalated} escalated`}
          icon={<Activity size={18} />}
          tone="brand"
        />
        <StatCard
          label="SLA breached"
          value={kpis.sla_breached}
          hint={`${data.sla.at_risk} at risk within 24h`}
          icon={<TriangleAlert size={18} />}
          tone="danger"
        />
        <StatCard
          label="Resolution rate"
          value={`${kpis.resolution_rate}%`}
          hint={`${kpis.resolved} of ${kpis.total} resolved all-time`}
          icon={<CheckCircle2 size={18} />}
          tone="success"
        />
        <StatCard
          label="Avg. resolution"
          value={kpis.avg_resolution_hours ? formatHours(kpis.avg_resolution_hours) : "—"}
          hint="Filing to verified resolution"
          icon={<Clock3 size={18} />}
          tone="neutral"
        />
        <StatCard
          label="Filed in 30 days"
          value={kpis.new_in_period}
          hint={`${kpis.total} all-time records`}
          icon={<CalendarClock size={18} />}
          tone="warn"
        />
        {isStaff && (
          <StatCard
            label={user.role === "admin" ? "Assigned workload" : "Your assignment load"}
            value={data.my.assigned}
            hint="Active complaints with an owner"
            icon={<MapPin size={18} />}
            tone="neutral"
          />
        )}
      </div>

      <div className="dashboard-grid">
        <SectionCard
          title="Case volume & resolution"
          description="Filed versus resolved complaints over the last 30 days"
          className="span-8"
          action={
            <div className="chart-legend">
              <span>
                <i style={{ background: "#0e7c66" }} /> Filed
              </span>
              <span>
                <i style={{ background: "#e0a028" }} /> Resolved
              </span>
            </div>
          }
        >
          <VolumeChart trend={data.trend} />
        </SectionCard>

        <SectionCard title="SLA health" description="Open-case deadline status" className="span-4">
          <SlaRing sla={data.sla} />
        </SectionCard>

        <SectionCard
          title="Case status"
          description="Current distribution across the workflow"
          className="span-4"
        >
          <StatusDonut data={statusData} centerLabel="total cases" centerValue={kpis.total} />
        </SectionCard>

        <SectionCard
          title="Priority mix"
          description="Open and closed complaints by urgency"
          className="span-4"
          action={<Link to="/complaints" className="text-link">All cases</Link>}
        >
          <ul className="bar-list">
            {data.priority_breakdown.map((entry) => {
              const meta = priorityMeta[entry.priority];
              return (
                <li key={entry.priority}>
                  <div className="bar-list__label">
                    <span className="dot" style={{ background: meta.dot }} />
                    {meta.label}
                    <strong>{entry.count}</strong>
                  </div>
                  <div className="bar-list__track">
                    <span
                      className="bar-list__fill"
                      style={{
                        width: `${(entry.count / priorityMax) * 100}%`,
                        background: meta.dot,
                      }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
          <div className="mini-note">
            <Siren size={14} />
            {kpis.critical_open} critical cases are still open
          </div>
        </SectionCard>

        <SectionCard
          title="Ward watchlist"
          description="Wards ranked by breached and open workload"
          className="span-4"
          action={<Link to="/map" className="text-link">Open map</Link>}
        >
          {data.wards.length === 0 ? (
            <EmptyState title="No ward data yet" />
          ) : (
            <ul className="watchlist">
              {data.wards.slice(0, 5).map((ward) => (
                <li key={ward.ward}>
                  <div>
                    <strong>{ward.ward}</strong>
                    <span>
                      {ward.open} open · {ward.total} total
                    </span>
                  </div>
                  <span
                    className={cn(
                      "watchlist__badge",
                      ward.breached > 0 && "watchlist__badge--alert",
                    )}
                  >
                    {ward.breached > 0 ? `${ward.breached} breached` : "On track"}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>

        <SectionCard
          title="Active complaint map"
          description={`${data.map_points.length} geotagged records in view`}
          className="span-8"
          action={<Link to="/map" className="text-link">Full map</Link>}
          bodyClassName="card__body--flush"
        >
          <ComplaintMap points={data.map_points.slice(0, 150)} height={330} />
        </SectionCard>

        {isStaff && (
          <SectionCard
            title="Department performance"
            description="SLA compliance and resolution time by department"
            className="span-12"
            action={<Link to="/analytics" className="text-link">Analytics</Link>}
            bodyClassName="card__body--flush"
          >
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Department</th>
                    <th>Total</th>
                    <th>Open</th>
                    <th>Escalated</th>
                    <th>Breached</th>
                    <th>Avg. resolution</th>
                    <th>SLA compliance</th>
                  </tr>
                </thead>
                <tbody>
                  {data.departments.map((dept) => (
                    <tr
                      key={dept.id}
                      onClick={() => navigate(`/complaints?department_id=${dept.id}`)}
                      tabIndex={0}
                      onKeyDown={(event) => {
                        if (event.key === "Enter") navigate(`/complaints?department_id=${dept.id}`);
                      }}
                    >
                      <td>
                        <div className="cell-title">
                          <strong>{dept.name}</strong>
                          <span>{dept.code}</span>
                        </div>
                      </td>
                      <td>{dept.total}</td>
                      <td>{dept.open}</td>
                      <td>{dept.escalated}</td>
                      <td className={dept.breached ? "text-danger" : ""}>{dept.breached}</td>
                      <td>{dept.avg_resolution_hours ? formatHours(dept.avg_resolution_hours) : "—"}</td>
                      <td>
                        <div className="inline-meter">
                          <span className="inline-meter__track">
                            <span
                              className={cn(
                                "inline-meter__fill",
                                dept.sla_compliance_rate < 70 && "is-warn",
                              )}
                              style={{ width: `${Math.min(100, dept.sla_compliance_rate)}%` }}
                            />
                          </span>
                          <strong>{dept.sla_compliance_rate}%</strong>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </SectionCard>
        )}

        <SectionCard
          title="Needs attention"
          description="Past SLA — highest urgency first"
          className="span-7"
          action={<Link to="/complaints?overdue=true" className="text-link">View all</Link>}
        >
          {attention.isLoading ? (
            <div className="inline-loading">Loading queue…</div>
          ) : attention.data && attention.data.length > 0 ? (
            <ul className="attention-list">
              {attention.data.map((complaint) => {
                const sla = slaState(complaint.due_at, complaint.status);
                return (
                  <li key={complaint.id}>
                    <button type="button" onClick={() => navigate(`/complaints/${complaint.id}`)}>
                      <div className="attention-list__main">
                        <span className="mono">{complaint.complaint_number}</span>
                        <strong>{complaint.title}</strong>
                        <span>
                          <MapPin size={12} /> {complaint.ward} · {formatDate(complaint.created_at)}
                        </span>
                      </div>
                      <div className="attention-list__meta">
                        <PriorityBadge priority={complaint.priority} />
                        <span className={cn("sla", `sla--${sla.state}`)}>
                          <span className="sla__dot" />
                          {sla.label}
                        </span>
                      </div>
                    </button>
                  </li>
                );
              })}
            </ul>
          ) : (
            <EmptyState
              title="Nothing overdue"
              description="Every open complaint is still inside its SLA window."
              icon={<CheckCircle2 size={22} />}
            />
          )}
        </SectionCard>

        <SectionCard
          title="Recent activity"
          description="Latest status changes across the municipality"
          className="span-5"
        >
          {data.recent_activity.length === 0 ? (
            <EmptyState title="No activity recorded yet" />
          ) : (
            <ol className="activity-feed">
              {data.recent_activity.slice(0, 8).map((item) => (
                <li key={item.id}>
                  <span
                    className="activity-feed__dot"
                    style={{
                      background: statusMeta[item.new_status as keyof typeof statusMeta]?.dot ?? "#94a3b8",
                    }}
                  />
                  <div>
                    <p>
                      <strong>{item.complaint_number}</strong> moved to{" "}
                      <StatusBadge status={item.new_status as ComplaintStatus} />
                    </p>
                    <span>
                      {item.actor} · {relativeTime(item.created_at)}
                    </span>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </SectionCard>
      </div>

      <Card className="dashboard-footer-note">
        <div>
          <ShieldAlert size={16} />
          <span>
            Data refreshed {analytics.dataUpdatedAt ? relativeTime(new Date(analytics.dataUpdatedAt).toISOString()) : "just now"} · Signed in as {user.email}
          </span>
        </div>
        <span className="mono">CivicAI v1.1</span>
      </Card>

      {user.role === "citizen" && (
        <p className="page-fineprint">
          Need urgent help? Call the municipal control room at <strong>1533</strong> or file a
          complaint above.
        </p>
      )}
    </div>
  );
}
