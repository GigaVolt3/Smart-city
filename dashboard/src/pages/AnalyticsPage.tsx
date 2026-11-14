import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Activity,
  ArrowRight,
  BarChart3,
  CalendarRange,
  CheckCircle2,
  Clock3,
  Download,
  RefreshCw,
  ShieldAlert,
  TriangleAlert,
} from "lucide-react";
import {
  Button,
  ErrorState,
  PageHeader,
  PageSkeleton,
  SectionCard,
} from "../components/ui/primitives";
import { StatCard } from "../components/dashboard/StatCard";
import { VolumeChart, StatusDonut, SlaRing } from "../components/charts/Charts";
import { useAnalytics } from "../hooks/queries";
import { cn, downloadCsv, formatHours, priorityMeta, statusMeta } from "../lib/utils";

const RANGES = [
  { value: 7, label: "7 days" },
  { value: 30, label: "30 days" },
  { value: 90, label: "90 days" },
  { value: 180, label: "6 months" },
];

export function AnalyticsPage() {
  const [days, setDays] = useState(30);
  const analytics = useAnalytics(days);
  const navigate = useNavigate();

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
  const statusData = data.status_breakdown
    .filter((entry) => entry.count > 0)
    .map((entry) => ({
      name: statusMeta[entry.status]?.label ?? entry.status,
      value: entry.count,
      color: statusMeta[entry.status]?.dot ?? "#94a3b8",
    }));
  const maxCategory = Math.max(1, ...data.categories.map((entry) => entry.count));

  return (
    <div className="page">
      <PageHeader
        eyebrow="Performance intelligence"
        title="Municipal analytics"
        description={`Operational performance for the last ${days} days, scoped to your role and department access.`}
        actions={
          <>
            <div className="segmented" role="group" aria-label="Analytics period">
              {RANGES.map((range) => (
                <button
                  key={range.value}
                  type="button"
                  className={cn(days === range.value && "is-active")}
                  onClick={() => setDays(range.value)}
                >
                  {range.label}
                </button>
              ))}
            </div>
            <Button
              variant="outline"
              size="sm"
              icon={<RefreshCw size={15} className={cn(analytics.isFetching && "spin")} />}
              onClick={() => analytics.refetch()}
            >
              Refresh
            </Button>
            <Button
              variant="outline"
              size="sm"
              icon={<Download size={15} />}
              onClick={() =>
                downloadCsv(
                  `department-performance-${days}d.csv`,
                  data.departments.map((dept) => ({
                    department: dept.name,
                    code: dept.code,
                    total: dept.total,
                    open: dept.open,
                    resolved: dept.resolved,
                    escalated: dept.escalated,
                    breached: dept.breached,
                    sla_compliance_rate: dept.sla_compliance_rate,
                    avg_resolution_hours: dept.avg_resolution_hours,
                  })),
                )
              }
            >
              Export
            </Button>
          </>
        }
      />

      <div className="kpi-grid kpi-grid--four">
        <StatCard
          label="Total cases"
          value={kpis.total}
          hint={`${kpis.new_in_period} filed in period`}
          icon={<BarChart3 size={18} />}
          tone="brand"
        />
        <StatCard
          label="Resolution rate"
          value={`${kpis.resolution_rate}%`}
          hint={`${kpis.resolved} of ${kpis.total} closed`}
          icon={<CheckCircle2 size={18} />}
          tone="success"
        />
        <StatCard
          label="SLA compliance"
          value={`${kpis.sla_compliance_rate}%`}
          hint={`${kpis.sla_breached} open cases breached`}
          icon={<ShieldAlert size={18} />}
          tone="danger"
        />
        <StatCard
          label="Avg. resolution"
          value={kpis.avg_resolution_hours ? formatHours(kpis.avg_resolution_hours) : "—"}
          hint="Time to verified closure"
          icon={<Clock3 size={18} />}
          tone="neutral"
        />
      </div>

      <div className="analytics-grid">
        <SectionCard
          title="Filed versus resolved"
          description={`Daily volume over the last ${days} days`}
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

        <SectionCard
          title="SLA health"
          description="Open complaints by deadline state"
          className="span-4"
        >
          <SlaRing sla={data.sla} />
        </SectionCard>

        <SectionCard
          title="Status distribution"
          description="Workflow position of every case"
          className="span-4"
        >
          <StatusDonut data={statusData} centerLabel="cases" centerValue={kpis.total} />
        </SectionCard>

        <SectionCard
          title="Priority profile"
          description="Volume by urgency level"
          className="span-4"
        >
          <ul className="bar-list">
            {data.priority_breakdown.map((entry) => {
              const meta = priorityMeta[entry.priority];
              const max = Math.max(1, ...data.priority_breakdown.map((item) => item.count));
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
                      style={{ width: `${(entry.count / max) * 100}%`, background: meta.dot }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
          <div className="mini-note">
            <TriangleAlert size={14} />
            {kpis.critical_open} critical cases remain open
          </div>
        </SectionCard>

        <SectionCard
          title="Top complaint categories"
          description="Where demand concentrates"
          className="span-4"
        >
          {data.categories.length === 0 ? (
            <p className="inline-loading">No categorised complaints yet.</p>
          ) : (
            <ul className="bar-list">
              {data.categories.slice(0, 6).map((entry) => (
                <li key={entry.id}>
                  <div className="bar-list__label">
                    <span>{entry.name}</span>
                    <strong>{entry.count}</strong>
                  </div>
                  <div className="bar-list__track">
                    <span
                      className="bar-list__fill"
                      style={{ width: `${(entry.count / maxCategory) * 100}%`, background: "#0e7c66" }}
                    />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>

        <SectionCard
          title="Department scorecard"
          description="SLA compliance, workload and resolution speed"
          className="span-12"
          action={
            <Link to="/departments" className="text-link">
              Manage departments
            </Link>
          }
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
                  <th aria-label="Open" />
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
                    <td>
                      <ArrowRight size={15} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </SectionCard>

        <SectionCard
          title="Ward workload"
          description="Open cases and SLA breaches by ward"
          className="span-7"
          action={
            <Link to="/map" className="text-link">
              Open map
            </Link>
          }
          bodyClassName="card__body--flush"
        >
          {data.wards.length === 0 ? (
            <div className="inline-loading">No ward data recorded.</div>
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Ward</th>
                    <th>Total</th>
                    <th>Open</th>
                    <th>Breached</th>
                    <th>Load</th>
                  </tr>
                </thead>
                <tbody>
                  {data.wards.map((ward) => {
                    const maxWard = Math.max(1, ...data.wards.map((item) => item.total));
                    return (
                      <tr key={ward.ward}>
                        <td>
                          <strong>{ward.ward}</strong>
                        </td>
                        <td>{ward.total}</td>
                        <td>{ward.open}</td>
                        <td className={ward.breached ? "text-danger" : ""}>{ward.breached}</td>
                        <td>
                          <div className="inline-meter">
                            <span className="inline-meter__track">
                              <span
                                className={cn("inline-meter__fill", ward.breached > 0 && "is-warn")}
                                style={{ width: `${(ward.total / maxWard) * 100}%` }}
                              />
                            </span>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </SectionCard>

        <SectionCard
          title="Recent resolution activity"
          description="Latest status transitions"
          className="span-5"
        >
          {data.recent_activity.length === 0 ? (
            <p className="inline-loading">No activity in this period.</p>
          ) : (
            <ol className="activity-feed">
              {data.recent_activity.slice(0, 10).map((item) => (
                <li key={item.id}>
                  <span
                    className="activity-feed__dot"
                    style={{
                      background:
                        statusMeta[item.new_status as keyof typeof statusMeta]?.dot ?? "#94a3b8",
                    }}
                  />
                  <div>
                    <p>
                      <Link to={`/complaints/${item.complaint_id}`} className="text-link">
                        {item.complaint_number}
                      </Link>{" "}
                      → {statusMeta[item.new_status as keyof typeof statusMeta]?.label ?? item.new_status}
                    </p>
                    <span>
                      {item.actor} · {item.title}
                    </span>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </SectionCard>
      </div>

      <div className="analytics-footer">
        <span>
          <CalendarRange size={14} /> Window: last {days} days · {kpis.resolved_in_period} resolutions ·{" "}
          {kpis.rejected} rejections
        </span>
        <span>
          <Activity size={14} /> Data refreshes every 30 seconds
        </span>
      </div>
    </div>
  );
}
