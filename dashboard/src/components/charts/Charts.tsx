import {
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { AnalyticsOverview } from "../../lib/types";
import { statusMeta } from "../../lib/utils";

const axisStyle = {
  fontSize: 11,
  fill: "#667085",
  fontFamily: "inherit",
};

const tooltipStyle = {
  border: "1px solid #e4e7ec",
  borderRadius: 10,
  boxShadow: "0 8px 24px rgba(16,24,40,0.08)",
  fontSize: 12,
  padding: "8px 10px",
};

export function VolumeChart({ trend }: { trend: AnalyticsOverview["trend"] }) {
  const formatted = trend.map((point) => ({
    ...point,
    label: new Date(`${point.date}T00:00:00`).toLocaleDateString("en-IN", {
      day: "2-digit",
      month: "short",
    }),
  }));

  return (
    <ResponsiveContainer width="100%" height={280}>
      <AreaChart data={formatted} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <defs>
          <linearGradient id="submittedFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#0e7c66" stopOpacity={0.18} />
            <stop offset="100%" stopColor="#0e7c66" stopOpacity={0.01} />
          </linearGradient>
          <linearGradient id="resolvedFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#f5b942" stopOpacity={0.16} />
            <stop offset="100%" stopColor="#f5b942" stopOpacity={0.01} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke="#eef0f3" vertical={false} />
        <XAxis
          dataKey="label"
          tick={axisStyle}
          tickLine={false}
          axisLine={false}
          interval="preserveStartEnd"
          minTickGap={28}
        />
        <YAxis tick={axisStyle} tickLine={false} axisLine={false} allowDecimals={false} />
        <Tooltip
          contentStyle={tooltipStyle}
          labelStyle={{ fontWeight: 600, color: "#101828", marginBottom: 4 }}
        />
        <Area
          type="monotone"
          dataKey="submitted"
          name="Filed"
          stroke="#0e7c66"
          strokeWidth={2}
          fill="url(#submittedFill)"
          dot={false}
          activeDot={{ r: 4 }}
        />
        <Area
          type="monotone"
          dataKey="resolved"
          name="Resolved"
          stroke="#e0a028"
          strokeWidth={2}
          fill="url(#resolvedFill)"
          dot={false}
          activeDot={{ r: 4 }}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}

export function StatusDonut({
  data,
  centerLabel,
  centerValue,
}: {
  data: Array<{ name: string; value: number; color: string }>;
  centerLabel: string;
  centerValue: string | number;
}) {
  const total = data.reduce((sum, item) => sum + item.value, 0);

  return (
    <div className="donut">
      <ResponsiveContainer width="100%" height={220}>
        <PieChart>
          <Pie
            data={data.length ? data : [{ name: "No data", value: 1, color: "#eef0f3" }]}
            dataKey="value"
            nameKey="name"
            innerRadius={64}
            outerRadius={88}
            paddingAngle={2}
            strokeWidth={0}
          >
            {(data.length ? data : [{ name: "No data", value: 1, color: "#eef0f3" }]).map(
              (entry) => (
                <Cell key={entry.name} fill={entry.color} />
              ),
            )}
          </Pie>
          {total > 0 && (
            <Tooltip contentStyle={tooltipStyle} formatter={(value) => [value, ""]} />
          )}
        </PieChart>
      </ResponsiveContainer>
      <div className="donut__center">
        <strong>{centerValue}</strong>
        <span>{centerLabel}</span>
      </div>
      <ul className="donut__legend">
        {data.map((entry) => (
          <li key={entry.name}>
            <span className="dot" style={{ backgroundColor: entry.color }} />
            <span>{entry.name}</span>
            <strong>{entry.value}</strong>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function SlaRing({ sla }: { sla: AnalyticsOverview["sla"] }) {
  const total = sla.on_track + sla.at_risk + sla.breached;
  const compliance =
    total > 0 ? Math.round((sla.on_track / total) * 100) : 0;

  return (
    <div className="sla-panel">
      <div className="sla-panel__ring">
        <ResponsiveContainer width="100%" height={150}>
          <PieChart>
            <Pie
              data={[
                { name: "On track", value: Math.max(sla.on_track, 0.0001), color: "#0e7c66" },
                { name: "At risk", value: Math.max(sla.at_risk, 0.0001), color: "#f5b942" },
                { name: "Breached", value: Math.max(sla.breached, 0.0001), color: "#dc2626" },
              ]}
              dataKey="value"
              innerRadius={48}
              outerRadius={66}
              startAngle={90}
              endAngle={-270}
              strokeWidth={0}
            >
              <Cell fill="#0e7c66" />
              <Cell fill="#f5b942" />
              <Cell fill="#dc2626" />
            </Pie>
          </PieChart>
        </ResponsiveContainer>
        <div className="sla-panel__center">
          <strong>{compliance}%</strong>
          <span>within SLA</span>
        </div>
      </div>
      <dl className="sla-panel__stats">
        <div>
          <dt>
            <span className="dot" style={{ background: "#0e7c66" }} /> On track
          </dt>
          <dd>{sla.on_track}</dd>
        </div>
        <div>
          <dt>
            <span className="dot" style={{ background: "#f5b942" }} /> At risk
          </dt>
          <dd>{sla.at_risk}</dd>
        </div>
        <div>
          <dt>
            <span className="dot" style={{ background: "#dc2626" }} /> Breached
          </dt>
          <dd>{sla.breached}</dd>
        </div>
      </dl>
    </div>
  );
}

export function StatusLegend({ status_breakdown }: { status_breakdown: AnalyticsOverview["status_breakdown"] }) {
  return (
    <ul className="status-legend">
      {status_breakdown.map((entry) => {
        const meta = statusMeta[entry.status];
        return (
          <li key={entry.status}>
            <span className="dot" style={{ backgroundColor: meta.dot }} />
            <span>{meta.label}</span>
            <strong>{entry.count}</strong>
          </li>
        );
      })}
    </ul>
  );
}
