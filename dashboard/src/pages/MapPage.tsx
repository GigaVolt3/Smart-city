import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import {
  Crosshair,
  Layers,
  ListFilter,
  MapPin,
  Radar,
  RotateCcw,
  Search,
} from "lucide-react";
import {
  Button,
  Card,
  ErrorState,
  PageSkeleton,
  Select,
  StatusBadge,
  PriorityBadge,
} from "../components/ui/primitives";
import { ComplaintMap } from "../components/maps/ComplaintMap";
import { useAnalytics } from "../hooks/queries";
import { api } from "../lib/api";
import type { ComplaintStatus, HotspotsResult, Priority } from "../lib/types";
import { cn, priorityMeta, statusMeta, WARDS } from "../lib/utils";

export function MapPage() {
  const analytics = useAnalytics(30);
  const hotspots = useQuery({
    queryKey: ["hotspots", 90],
    queryFn: () => api.get<HotspotsResult>("/ai/hotspots", { days_back: 90 }),
    staleTime: 5 * 60_000,
    retry: 1,
  });

  const [status, setStatus] = useState<"" | ComplaintStatus>("");
  const [priority, setPriority] = useState<"" | Priority>("");
  const [ward, setWard] = useState("");
  const [search, setSearch] = useState("");
  const [showHotspots, setShowHotspots] = useState(false);

  const allPoints = analytics.data?.map_points ?? [];

  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return allPoints.filter((point) => {
      if (status && point.status !== status) return false;
      if (priority && point.priority !== priority) return false;
      if (ward && point.ward !== ward) return false;
      if (
        term &&
        !`${point.complaint_number} ${point.title} ${point.ward} ${point.category}`
          .toLowerCase()
          .includes(term)
      )
        return false;
      return true;
    });
  }, [allPoints, search, status, priority, ward]);

  const activeFilters = [status, priority, ward, search].filter(Boolean).length;

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

  const summary = hotspots.data?.summary;

  return (
    <div className="page map-page">
      <header className="map-hero">
        <div>
          <p className="page-header__eyebrow">Geospatial operations</p>
          <h1>Live complaint map</h1>
          <p>
            {allPoints.length} geotagged records · {visible.length} shown · campaign view for
            Bengaluru wards
          </p>
        </div>
        <div className="map-hero__actions">
          <Button
            variant={showHotspots ? "secondary" : "outline"}
            size="sm"
            icon={<Radar size={15} />}
            onClick={() => setShowHotspots((value) => !value)}
          >
            {showHotspots ? "Hide hotspots" : "Show AI hotspots"}
          </Button>
          {activeFilters > 0 && (
            <Button
              variant="ghost"
              size="sm"
              icon={<RotateCcw size={15} />}
              onClick={() => {
                setStatus("");
                setPriority("");
                setWard("");
                setSearch("");
              }}
            >
              Reset
            </Button>
          )}
        </div>
      </header>

      <div className="map-layout">
        <Card className="map-canvas-card" padded={false}>
          <div className="map-toolbar">
            <div className="map-search">
              <Search size={15} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search plotted complaints…"
                aria-label="Search plotted complaints"
              />
            </div>

            <Select
              value={status}
              onChange={(event) => setStatus(event.target.value as "" | ComplaintStatus)}
              aria-label="Filter map by status"
            >
              <option value="">All statuses</option>
              {Object.entries(statusMeta).map(([value, meta]) => (
                <option key={value} value={value}>
                  {meta.label}
                </option>
              ))}
            </Select>

            <Select
              value={priority}
              onChange={(event) => setPriority(event.target.value as "" | Priority)}
              aria-label="Filter map by priority"
            >
              <option value="">All priorities</option>
              {Object.entries(priorityMeta)
                .sort(([, a], [, b]) => b.rank - a.rank)
                .map(([value, meta]) => (
                  <option key={value} value={value}>
                    {meta.label}
                  </option>
                ))}
            </Select>

            <Select
              value={ward}
              onChange={(event) => setWard(event.target.value)}
              aria-label="Filter map by ward"
            >
              <option value="">All wards</option>
              {WARDS.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </Select>
          </div>

          <ComplaintMap
            points={visible}
            hotspots={hotspots.data?.hotspots ?? []}
            showHotspots={showHotspots}
            height={560}
          />

          <div className="map-legend">
            <span>
              <i style={{ background: priorityMeta.critical.dot }} /> Critical
            </span>
            <span>
              <i style={{ background: priorityMeta.high.dot }} /> High
            </span>
            <span>
              <i style={{ background: priorityMeta.medium.dot }} /> Medium
            </span>
            <span>
              <i style={{ background: priorityMeta.low.dot }} /> Low
            </span>
            <span className="map-legend__note">
              <Crosshair size={13} /> Markers coloured by priority
            </span>
          </div>
        </Card>

        <aside className="map-side">
          <Card className="side-card">
            <h2 className="side-card__title">
              <ListFilter size={16} /> In view
            </h2>
            <div className="map-counts">
              <div>
                <strong>{visible.length}</strong>
                <span>plotted</span>
              </div>
              <div>
                <strong>{visible.filter((point) => point.status === "escalated").length}</strong>
                <span>escalated</span>
              </div>
              <div>
                <strong>{visible.filter((point) => point.priority === "critical").length}</strong>
                <span>critical</span>
              </div>
            </div>

            {visible.length === 0 ? (
              <p className="map-side__empty">
                No complaints match the current map filters. Reset filters or change the search
                term.
              </p>
            ) : (
              <ul className="map-list">
                {visible.slice(0, 10).map((point) => (
                  <li key={point.id}>
                    <Link to={`/complaints/${point.id}`}>
                      <span className="mono">{point.complaint_number}</span>
                      <strong>{point.title}</strong>
                      <span className="map-list__meta">
                        <MapPin size={12} /> {point.ward}
                      </span>
                      <span className="map-list__badges">
                        <StatusBadge status={point.status} />
                        <PriorityBadge priority={point.priority} />
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
            {visible.length > 10 && (
              <p className="map-side__more">+{visible.length - 10} more markers on the map</p>
            )}
          </Card>

          <Card className="side-card">
            <h2 className="side-card__title">
              <Radar size={16} /> Recurring hotspots
            </h2>
            {hotspots.isLoading ? (
              <p className="map-side__empty">Clustering recent complaints…</p>
            ) : hotspots.error ? (
              <div className="inline-error">
                Hotspot analysis is unavailable. {hotspots.error instanceof Error ? hotspots.error.message : ""}
              </div>
            ) : hotspots.data ? (
              <>
                <p className="map-side__lead">
                  {hotspots.data.total_hotspots} clusters across{" "}
                  {hotspots.data.total_complaints_analyzed} complaints in the last 90 days.
                </p>
                <ul className="hotspot-list">
                  {hotspots.data.hotspots.slice(0, 4).map((hotspot) => (
                    <li key={hotspot.hotspot_id}>
                      <div className="hotspot-list__head">
                        <strong>{hotspot.affected_wards[0] ?? "Unmapped cluster"}</strong>
                        <span
                          className={cn(
                            "badge",
                            hotspot.severity_tier === "critical" || hotspot.severity_tier === "high"
                              ? "badge--escalated"
                              : "badge--progress",
                          )}
                        >
                          {hotspot.severity_tier}
                        </span>
                      </div>
                      <p>
                        {hotspot.total_complaints} reports · {hotspot.open_complaints} open ·{" "}
                        {Math.round(hotspot.radius_meters)} m radius
                      </p>
                      <span className="hotspot-list__meta">
                        Recurrence score {Math.round(hotspot.recurrence_score)}/100
                      </span>
                    </li>
                  ))}
                </ul>
                {summary && (
                  <dl className="side-facts hotspot-summary">
                    <div>
                      <dt>Most affected ward</dt>
                      <dd>{summary.most_critical_ward ?? "—"}</dd>
                    </div>
                    <div>
                      <dt>Top recurring category</dt>
                      <dd>{summary.top_recurring_category ?? "—"}</dd>
                    </div>
                    <div>
                      <dt>Avg. cluster size</dt>
                      <dd>{summary.avg_cluster_size}</dd>
                    </div>
                  </dl>
                )}
              </>
            ) : null}
          </Card>

          <Card className="side-card">
            <h2 className="side-card__title">
              <Layers size={16} /> Map data
            </h2>
            <p className="map-side__lead">
              Base map tiles are served by OpenStreetMap. Complaint coordinates come from the
              civic database; hotspots are recomputed from the last 90 days of reports.
            </p>
            <Link to="/complaints" className="text-link">
              Browse the complaint queue
            </Link>
          </Card>
        </aside>
      </div>
    </div>
  );
}
