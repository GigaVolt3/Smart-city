import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { Download, FilterX, Plus, SlidersHorizontal } from "lucide-react";
import {
  Button,
  ErrorState,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  Skeleton,
} from "../components/ui/primitives";
import { ComplaintTable } from "../components/complaints/ComplaintList";
import { useComplaintPage, useLookups } from "../hooks/queries";
import { useAuth } from "../providers/AuthProvider";
import { downloadCsv, formatDate, statusMeta, priorityMeta } from "../lib/utils";
import { useNavigate } from "react-router-dom";

const PAGE_SIZE = 12;

export function ComplaintsPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const { departments, categories, isLoading: lookupsLoading } = useLookups();
  const [searchDraft, setSearchDraft] = useState(params.get("search") ?? "");

  const page = Math.max(1, Number(params.get("page") ?? 1));
  const filters = useMemo(
    () => ({
      search: params.get("search") ?? undefined,
      status: params.get("status") ?? undefined,
      priority: params.get("priority") ?? undefined,
      department_id: params.get("department_id") ?? undefined,
      category_id: params.get("category_id") ?? undefined,
      overdue: params.get("overdue") === "true",
      assigned_to_me: params.get("assigned_to_me") === "true",
      skip: (page - 1) * PAGE_SIZE,
      limit: PAGE_SIZE,
    }),
    [params, page],
  );

  const complaints = useComplaintPage(filters);
  const isStaff = user?.role !== "citizen";

  const updateParam = (key: string, value?: string) => {
    setParams((previous) => {
      const next = new URLSearchParams(previous);
      if (value) next.set(key, value);
      else next.delete(key);
      if (key !== "page") next.delete("page");
      return next;
    }, { replace: true });
  };

  useEffect(() => {
    setSearchDraft(params.get("search") ?? "");
  }, [params]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const current = params.get("search") ?? "";
      if (searchDraft !== current) updateParam("search", searchDraft.trim() || undefined);
    }, 350);
    return () => window.clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchDraft]);

  const activeCount = [
    "search",
    "status",
    "priority",
    "department_id",
    "category_id",
    "overdue",
    "assigned_to_me",
  ].filter((key) => params.get(key)).length;

  const filteredCategories = filters.department_id
    ? categories.filter((category) => String(category.department_id) === filters.department_id)
    : categories;

  const labelFor = (key: string) => {
    if (key === "search") return `“${params.get("search")}”`;
    if (key === "status") return statusMeta[params.get("status") as keyof typeof statusMeta]?.label;
    if (key === "priority") return priorityMeta[params.get("priority") as keyof typeof priorityMeta]?.label;
    if (key === "department_id")
      return departments.find((dept) => String(dept.id) === params.get("department_id"))?.name;
    if (key === "category_id")
      return categories.find((category) => String(category.id) === params.get("category_id"))?.name;
    if (key === "overdue") return "Past SLA";
    if (key === "assigned_to_me") return "Assigned to me";
    return key;
  };

  return (
    <div className="page">
      <PageHeader
        eyebrow="Case management"
        title={isStaff ? "Complaint queue" : "My complaints"}
        description={
          isStaff
            ? "Filter, prioritise and move civic cases through the resolution workflow."
            : "Track every grievance you have filed and its current status."
        }
        actions={
          <>
            <Button
              variant="outline"
              size="sm"
              icon={<Download size={15} />}
              disabled={!complaints.data?.items.length}
              onClick={() =>
                downloadCsv(
                  `complaints-${formatDate(new Date().toISOString())}.csv`,
                  (complaints.data?.items ?? []).map((item) => ({
                    reference: item.complaint_number,
                    title: item.title,
                    ward: item.ward,
                    status: item.status,
                    priority: item.priority,
                    department: departments.find((d) => d.id === item.department_id)?.name ?? "",
                    filed: item.created_at,
                    due: item.due_at,
                  })),
                )
              }
            >
              Export page
            </Button>
            <Button size="sm" icon={<Plus size={15} />} onClick={() => navigate("/complaints/new")}>
              New complaint
            </Button>
          </>
        }
      />

      <section className="filter-bar">
        <div className="filter-bar__top">
          <SearchInput
            value={searchDraft}
            onChange={(event) => setSearchDraft(event.target.value)}
            placeholder="Search by reference, title, address…"
            aria-label="Search complaints"
          />
          <div className="filter-bar__count">
            <SlidersHorizontal size={15} />
            {complaints.data ? `${complaints.data.total} cases` : "Loading…"}
          </div>
        </div>

        <div className="filter-bar__grid">
          <Select
            value={params.get("status") ?? ""}
            onChange={(event) => updateParam("status", event.target.value || undefined)}
            aria-label="Filter by status"
          >
            <option value="">All statuses</option>
            {Object.entries(statusMeta).map(([value, meta]) => (
              <option key={value} value={value}>
                {meta.label}
              </option>
            ))}
          </Select>

          <Select
            value={params.get("priority") ?? ""}
            onChange={(event) => updateParam("priority", event.target.value || undefined)}
            aria-label="Filter by priority"
          >
            <option value="">All priorities</option>
            {Object.entries(priorityMeta).map(([value, meta]) => (
              <option key={value} value={value}>
                {meta.label}
              </option>
            ))}
          </Select>

          <Select
            value={params.get("department_id") ?? ""}
            onChange={(event) => {
              const next = new URLSearchParams(params);
              if (event.target.value) next.set("department_id", event.target.value);
              else next.delete("department_id");
              next.delete("category_id");
              next.delete("page");
              setParams(next, { replace: true });
            }}
            aria-label="Filter by department"
          >
            <option value="">All departments</option>
            {departments.map((department) => (
              <option key={department.id} value={department.id}>
                {department.name}
              </option>
            ))}
          </Select>

          <Select
            value={params.get("category_id") ?? ""}
            onChange={(event) => updateParam("category_id", event.target.value || undefined)}
            aria-label="Filter by category"
          >
            <option value="">All categories</option>
            {filteredCategories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </Select>

          {isStaff && (
            <label className="check-toggle">
              <input
                type="checkbox"
                checked={params.get("overdue") === "true"}
                onChange={(event) => updateParam("overdue", event.target.checked ? "true" : undefined)}
              />
              <span>Past SLA</span>
            </label>
          )}

          {isStaff && (
            <label className="check-toggle">
              <input
                type="checkbox"
                checked={params.get("assigned_to_me") === "true"}
                onChange={(event) =>
                  updateParam("assigned_to_me", event.target.checked ? "true" : undefined)
                }
              />
              <span>Assigned to me</span>
            </label>
          )}

          {activeCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              icon={<FilterX size={15} />}
              onClick={() => setParams(new URLSearchParams(), { replace: true })}
            >
              Clear filters
            </Button>
          )}
        </div>

        {activeCount > 0 && (
          <div className="filter-chips">
            {["search", "status", "priority", "department_id", "category_id", "overdue", "assigned_to_me"]
              .filter((key) => params.get(key))
              .map((key) => (
                <button
                  type="button"
                  key={key}
                  className="chip"
                  onClick={() => updateParam(key, undefined)}
                >
                  {labelFor(key)} <span aria-hidden>×</span>
                </button>
              ))}
          </div>
        )}
      </section>

      <section className="card card--flush">
        {complaints.isLoading || lookupsLoading ? (
          <div className="table-loading">
            {Array.from({ length: 6 }).map((_, index) => (
              <Skeleton key={index} className="skeleton--row" />
            ))}
          </div>
        ) : complaints.error ? (
          <ErrorState
            message={complaints.error instanceof Error ? complaints.error.message : undefined}
            onRetry={() => complaints.refetch()}
          />
        ) : (
          <ComplaintTable
            items={complaints.data?.items ?? []}
            departments={departments}
            categories={categories}
            emptyTitle={activeCount ? "No cases match these filters" : "No complaints yet"}
            emptyDescription={
              activeCount
                ? "Try removing a filter or searching a different reference."
                : "File the first complaint to begin tracking civic work."
            }
          />
        )}

        {complaints.data && complaints.data.total > 0 && (
          <Pagination
            page={page}
            pageSize={PAGE_SIZE}
            total={complaints.data.total}
            onPageChange={(nextPage) => updateParam("page", String(nextPage))}
          />
        )}
      </section>
    </div>
  );
}
