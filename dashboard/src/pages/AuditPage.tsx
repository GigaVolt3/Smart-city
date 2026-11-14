import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Download,
  FilterX,
  ScrollText,
  Search,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import {
  Button,
  Card,
  ErrorState,
  PageHeader,
  Select,
  Skeleton,
} from "../components/ui/primitives";
import { api } from "../lib/api";
import type { AuditEvent } from "../lib/types";
import { downloadCsv, formatDateTime, relativeTime } from "../lib/utils";

const PAGE_SIZE = 25;

const RESOURCE_TYPES = [
  "complaint",
  "user",
  "department",
  "category",
  "escalation_rule",
  "system",
];

export function AuditPage() {
  const [action, setAction] = useState("");
  const [resourceType, setResourceType] = useState("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);

  const audit = useQuery({
    queryKey: ["audit", { action, resourceType, page }],
    queryFn: () =>
      api.get<AuditEvent[]>("/audit", {
        action: action || undefined,
        resource_type: resourceType || undefined,
        skip: (page - 1) * PAGE_SIZE,
        limit: PAGE_SIZE,
      }),
    placeholderData: (previous) => previous,
  });

  const rows = (audit.data ?? []).filter((event) => {
    if (!search.trim()) return true;
    const term = search.trim().toLowerCase();
    return `${event.action} ${event.resource_type} ${event.resource_id ?? ""} ${
      event.user_name ?? ""
    } ${event.details ?? ""}`
      .toLowerCase()
      .includes(term);
  });

  const activeFilters = [action, resourceType, search].filter(Boolean).length;

  return (
    <div className="page">
      <PageHeader
        eyebrow="Governance"
        title="Audit trail"
        description="Immutable record of administrative and workflow actions across the municipality."
        actions={
          <>
            <Button
              variant="outline"
              size="sm"
              icon={<Download size={15} />}
              disabled={!rows.length}
              onClick={() =>
                downloadCsv(
                  `civicai-audit-${new Date().toISOString().slice(0, 10)}.csv`,
                  rows.map((event) => ({
                    timestamp: event.created_at,
                    actor: event.user_name ?? "System",
                    action: event.action,
                    resource: `${event.resource_type}:${event.resource_id ?? ""}`,
                    details: event.details ?? "",
                    ip: event.ip_address ?? "",
                  })),
                )
              }
            >
              Export page
            </Button>
            <Button
              variant="ghost"
              size="sm"
              icon={<FilterX size={15} />}
              disabled={activeFilters === 0}
              onClick={() => {
                setAction("");
                setResourceType("");
                setSearch("");
                setPage(1);
              }}
            >
              Clear
            </Button>
          </>
        }
      />

      <div className="audit-banner">
        <ShieldCheck size={18} />
        <div>
          <strong>Administrator-only evidence log</strong>
          <span>
            Audit records are append-only. Each entry captures the actor, resource, timestamp and
            request context.
          </span>
        </div>
        <span className="mono">{audit.data?.length ?? 0} rows loaded</span>
      </div>

      <section className="filter-bar">
        <div className="filter-bar__top">
          <div className="search-input">
            <Search size={16} aria-hidden />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search action, actor, resource or detail…"
              aria-label="Search audit events"
            />
          </div>
          <div className="filter-bar__count">{rows.length} visible</div>
        </div>
        <div className="filter-bar__grid">
          <Select
            value={resourceType}
            onChange={(event) => {
              setResourceType(event.target.value);
              setPage(1);
            }}
            aria-label="Filter by resource type"
          >
            <option value="">All resource types</option>
            {RESOURCE_TYPES.map((type) => (
              <option key={type} value={type}>
                {type.replaceAll("_", " ")}
              </option>
            ))}
          </Select>
          <Select
            value={action}
            onChange={(event) => {
              setAction(event.target.value);
              setPage(1);
            }}
            aria-label="Filter by action prefix"
          >
            <option value="">All actions</option>
            <option value="complaint">complaint.*</option>
            <option value="user">user.*</option>
            <option value="department">department.*</option>
            <option value="category">category.*</option>
            <option value="escalation">escalation.*</option>
          </Select>
        </div>
      </section>

      <Card padded={false} className="card--flush">
        {audit.isLoading ? (
          <div className="table-loading">
            {Array.from({ length: 8 }).map((_, index) => (
              <Skeleton key={index} className="skeleton--row" />
            ))}
          </div>
        ) : audit.error ? (
          <ErrorState
            message={audit.error instanceof Error ? audit.error.message : undefined}
            onRetry={() => audit.refetch()}
          />
        ) : rows.length === 0 ? (
          <div className="empty-state">
            <ScrollText size={24} />
            <h3>No audit entries match</h3>
            <p>Clear the filters or perform an administrative action to generate records.</p>
          </div>
        ) : (
          <>
            <div className="table-wrap table-desktop">
              <table className="data-table audit-table">
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Actor</th>
                    <th>Action</th>
                    <th>Resource</th>
                    <th>Details</th>
                    <th>IP</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((event) => (
                    <tr key={event.id}>
                      <td>
                        <div className="cell-title">
                          <strong>{relativeTime(event.created_at)}</strong>
                          <span className="mono">{formatDateTime(event.created_at)}</span>
                        </div>
                      </td>
                      <td>
                        <span className="person-inline">
                          <UserRound size={13} /> {event.user_name ?? "System"}
                        </span>
                      </td>
                      <td>
                        <code className="audit-action">{event.action}</code>
                      </td>
                      <td>
                        <div className="cell-title">
                          <strong>{event.resource_type}</strong>
                          <span className="mono">
                            {event.resource_id ? `#${event.resource_id}` : "—"}
                          </span>
                        </div>
                      </td>
                      <td className="audit-details">{event.details || "—"}</td>
                      <td className="cell-muted mono">{event.ip_address || "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <ul className="audit-cards cards-mobile">
              {rows.map((event) => (
                <li key={event.id}>
                  <div className="audit-cards__head">
                    <code className="audit-action">{event.action}</code>
                    <span>{relativeTime(event.created_at)}</span>
                  </div>
                  <p>
                    <strong>{event.resource_type}</strong>{" "}
                    {event.resource_id ? `#${event.resource_id}` : ""} ·{" "}
                    {event.user_name ?? "System"}
                  </p>
                  {event.details && <span>{event.details}</span>}
                  <small className="mono">{formatDateTime(event.created_at)}</small>
                </li>
              ))}
            </ul>
          </>
        )}

        <div className="pagination">
          <p>
            Page <strong>{page}</strong> · newest {PAGE_SIZE} records per page
          </p>
          <div className="pagination__controls">
            <Button
              variant="outline"
              size="sm"
              disabled={page <= 1}
              onClick={() => setPage((current) => Math.max(1, current - 1))}
            >
              Prev
            </Button>
            <span className="pagination__page">{page}</span>
            <Button
              variant="outline"
              size="sm"
              disabled={(audit.data?.length ?? 0) < PAGE_SIZE}
              onClick={() => setPage((current) => current + 1)}
            >
              Next
            </Button>
          </div>
        </div>
      </Card>

      <p className="page-fineprint">
        The audit endpoint returns the newest 25 records per page. Filter by action prefix (for
        example <code>user</code>) to narrow the trail.
      </p>
    </div>
  );
}
