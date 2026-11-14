import { ArrowUpRight, MapPin } from "lucide-react";
import { useNavigate } from "react-router-dom";
import type { Category, Complaint, Department } from "../../lib/types";
import { formatDate, slaState, cn } from "../../lib/utils";
import { EmptyState, PriorityBadge, StatusBadge } from "../ui/primitives";

type Props = {
  items: Complaint[];
  departments: Department[];
  categories: Category[];
  emptyTitle?: string;
  emptyDescription?: string;
};

function useLookups(departments: Department[], categories: Category[]) {
  const deptMap = new Map(departments.map((dept) => [dept.id, dept]));
  const categoryMap = new Map(categories.map((category) => [category.id, category]));
  return { deptMap, categoryMap };
}

function SlaCell({ complaint }: { complaint: Complaint }) {
  const sla = slaState(complaint.due_at, complaint.status);
  return (
    <span className={cn("sla", `sla--${sla.state}`)}>
      <span className="sla__dot" />
      {sla.label}
    </span>
  );
}

export function ComplaintTable({
  items,
  departments,
  categories,
  emptyTitle = "No complaints found",
  emptyDescription = "Adjust the filters or file a new complaint to get started.",
}: Props) {
  const navigate = useNavigate();
  const { deptMap, categoryMap } = useLookups(departments, categories);

  if (items.length === 0) {
    return <EmptyState title={emptyTitle} description={emptyDescription} />;
  }

  return (
    <>
      <div className="table-wrap table-desktop">
        <table className="data-table">
          <thead>
            <tr>
              <th>Reference</th>
              <th>Complaint</th>
              <th>Department</th>
              <th>Status</th>
              <th>Priority</th>
              <th>SLA</th>
              <th>Filed</th>
              <th aria-label="Open" />
            </tr>
          </thead>
          <tbody>
            {items.map((complaint) => {
              const dept = deptMap.get(complaint.department_id);
              const category = categoryMap.get(complaint.category_id);
              return (
                <tr
                  key={complaint.id}
                  onClick={() => navigate(`/complaints/${complaint.id}`)}
                  tabIndex={0}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") navigate(`/complaints/${complaint.id}`);
                  }}
                >
                  <td>
                    <span className="mono cell-ref">{complaint.complaint_number}</span>
                  </td>
                  <td>
                    <div className="cell-title">
                      <strong>{complaint.title}</strong>
                      <span>
                        <MapPin size={12} /> {complaint.ward}
                        {category ? ` · ${category.name}` : ""}
                      </span>
                    </div>
                  </td>
                  <td>{dept?.name ?? "—"}</td>
                  <td>
                    <StatusBadge status={complaint.status} />
                  </td>
                  <td>
                    <PriorityBadge priority={complaint.priority} />
                  </td>
                  <td>
                    <SlaCell complaint={complaint} />
                  </td>
                  <td className="cell-muted">{formatDate(complaint.created_at)}</td>
                  <td>
                    <span className="row-arrow">
                      <ArrowUpRight size={16} />
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="complaint-cards cards-mobile">
        {items.map((complaint) => {
          const dept = deptMap.get(complaint.department_id);
          return (
            <button
              type="button"
              key={complaint.id}
              className="complaint-card"
              onClick={() => navigate(`/complaints/${complaint.id}`)}
            >
              <div className="complaint-card__top">
                <span className="mono">{complaint.complaint_number}</span>
                <StatusBadge status={complaint.status} />
              </div>
              <h3>{complaint.title}</h3>
              <p>
                <MapPin size={13} /> {complaint.ward}
                {dept ? ` · ${dept.code}` : ""}
              </p>
              <div className="complaint-card__bottom">
                <PriorityBadge priority={complaint.priority} />
                <SlaCell complaint={complaint} />
                <span className="cell-muted">{formatDate(complaint.created_at)}</span>
              </div>
            </button>
          );
        })}
      </div>
    </>
  );
}
