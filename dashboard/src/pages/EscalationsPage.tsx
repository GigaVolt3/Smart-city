import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowUpRight,
  Building2,
  Clock3,
  Layers,
  Play,
  Plus,
  ShieldAlert,
  Trash2,
  Users,
} from "lucide-react";
import {
  Button,
  EmptyState,
  ErrorState,
  Field,
  Input,
  PageHeader,
  PageSkeleton,
  SectionCard,
  Select,
  Skeleton,
} from "../components/ui/primitives";
import { Modal } from "../components/ui/Modal";
import { useLookups } from "../hooks/queries";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { api } from "../lib/api";
import type { EscalationEvent, EscalationRule, EscalationSummary } from "../lib/types";
import { formatDateTime, relativeTime } from "../lib/utils";

const EMPTY_RULE = {
  department_id: "",
  category_id: "",
  escalation_level: "1",
  trigger_hours: "24",
  target_role: "supervisor",
};

export function EscalationsPage() {
  const { user } = useAuth();
  const { notify } = useToast();
  const queryClient = useQueryClient();
  const lookups = useLookups();
  const isAdmin = user?.role === "admin";

  const summary = useQuery({
    queryKey: ["escalations", "summary"],
    queryFn: () => api.get<EscalationSummary>("/escalations/summary"),
  });

  const events = useQuery({
    queryKey: ["escalations", "events"],
    queryFn: () => api.get<EscalationEvent[]>("/escalations/events", { limit: 100 }),
  });

  const rules = useQuery({
    queryKey: ["escalations", "rules"],
    queryFn: () => api.get<EscalationRule[]>("/escalations/rules"),
  });

  const [modalOpen, setModalOpen] = useState(false);
  const [ruleForm, setRuleForm] = useState(EMPTY_RULE);

  const runSweep = useMutation({
    mutationFn: () => api.post<{ escalated: number }>("/escalations/run"),
    onSuccess: (result) => {
      notify(
        result.escalated > 0
          ? `${result.escalated} complaint${result.escalated === 1 ? "" : "s"} escalated`
          : "No complaints are currently due for escalation",
        result.escalated > 0 ? "success" : "info",
      );
      queryClient.invalidateQueries({ queryKey: ["escalations"] });
      queryClient.invalidateQueries({ queryKey: ["complaints"] });
      queryClient.invalidateQueries({ queryKey: ["analytics"] });
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Escalation sweep failed", "error"),
  });

  const createRule = useMutation({
    mutationFn: () =>
      api.post<EscalationRule>("/escalations/rules", {
        department_id: ruleForm.department_id ? Number(ruleForm.department_id) : null,
        category_id: ruleForm.category_id ? Number(ruleForm.category_id) : null,
        escalation_level: Number(ruleForm.escalation_level),
        trigger_hours: Number(ruleForm.trigger_hours),
        target_role: ruleForm.target_role,
      }),
    onSuccess: () => {
      notify("Escalation rule created", "success");
      queryClient.invalidateQueries({ queryKey: ["escalations", "rules"] });
      setModalOpen(false);
      setRuleForm(EMPTY_RULE);
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not create rule", "error"),
  });

  const deleteRule = useMutation({
    mutationFn: (id: number) => api.delete(`/escalations/rules/${id}`),
    onSuccess: () => {
      notify("Escalation rule deleted", "info");
      queryClient.invalidateQueries({ queryKey: ["escalations", "rules"] });
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not delete rule", "error"),
  });

  const departmentMap = new Map(lookups.departments.map((item) => [item.id, item.name]));
  const categoryMap = new Map(lookups.categories.map((item) => [item.id, item.name]));

  if (summary.isLoading || events.isLoading) return <PageSkeleton />;

  if (summary.error || !summary.data) {
    return (
      <div className="page">
        <ErrorState
          message={summary.error instanceof Error ? summary.error.message : undefined}
          onRetry={() => summary.refetch()}
        />
      </div>
    );
  }

  const data = summary.data;
  const maxLevel = Math.max(1, ...Object.values(data.by_level));
  const maxDept = Math.max(1, ...data.by_department.map((item) => item.count));
  const filteredCategories = ruleForm.department_id
    ? lookups.categories.filter(
        (category) => String(category.department_id) === ruleForm.department_id,
      )
    : lookups.categories;

  return (
    <div className="page">
      <PageHeader
        eyebrow="Accountability"
        title="Escalation control"
        description="SLA breaches move complaints up the chain automatically. Supervisors can also run a sweep manually."
        actions={
          <>
            <Button
              variant="outline"
              size="sm"
              icon={<Play size={15} />}
              loading={runSweep.isPending}
              onClick={() => runSweep.mutate()}
            >
              Run sweep now
            </Button>
            {isAdmin && (
              <Button size="sm" icon={<Plus size={15} />} onClick={() => setModalOpen(true)}>
                New rule
              </Button>
            )}
          </>
        }
      />

      <div className="kpi-grid kpi-grid--four">
        <article className="stat-card stat-card--danger">
          <div className="stat-card__top">
            <span className="stat-card__icon">
              <ShieldAlert size={18} />
            </span>
          </div>
          <p className="stat-card__label">Open escalated</p>
          <p className="stat-card__value">{data.open_escalated}</p>
          <p className="stat-card__hint">Active cases above level zero</p>
        </article>
        <article className="stat-card stat-card--neutral">
          <div className="stat-card__top">
            <span className="stat-card__icon">
              <ArrowUpRight size={18} />
            </span>
          </div>
          <p className="stat-card__label">Total escalation events</p>
          <p className="stat-card__value">{data.total_events}</p>
          <p className="stat-card__hint">Recorded across all time</p>
        </article>
        <article className="stat-card stat-card--warn">
          <div className="stat-card__top">
            <span className="stat-card__icon">
              <Layers size={18} />
            </span>
          </div>
          <p className="stat-card__label">Rules configured</p>
          <p className="stat-card__value">{rules.data?.length ?? 0}</p>
          <p className="stat-card__hint">Automatic level triggers</p>
        </article>
        <article className="stat-card stat-card--brand">
          <div className="stat-card__top">
            <span className="stat-card__icon">
              <Building2 size={18} />
            </span>
          </div>
          <p className="stat-card__label">Departments affected</p>
          <p className="stat-card__value">{data.by_department.length}</p>
          <p className="stat-card__hint">With at least one escalation</p>
        </article>
      </div>

      <div className="escalation-grid">
        <SectionCard
          title="Escalations by level"
          description="Where cases sit in the accountability chain"
          className="span-5"
        >
          {Object.keys(data.by_level).length === 0 ? (
            <EmptyState title="No escalations recorded" />
          ) : (
            <ul className="bar-list">
              {Object.entries(data.by_level).map(([level, count]) => (
                <li key={level}>
                  <div className="bar-list__label">
                    <span>Level {level}</span>
                    <strong>{count}</strong>
                  </div>
                  <div className="bar-list__track">
                    <span
                      className="bar-list__fill"
                      style={{ width: `${(count / maxLevel) * 100}%`, background: "#dc2626" }}
                    />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>

        <SectionCard
          title="Escalations by department"
          description="Departments generating the most breach events"
          className="span-7"
        >
          {data.by_department.length === 0 ? (
            <EmptyState title="No department escalation data" />
          ) : (
            <ul className="bar-list">
              {data.by_department.map((item) => (
                <li key={item.department}>
                  <div className="bar-list__label">
                    <span>{item.department}</span>
                    <strong>{item.count}</strong>
                  </div>
                  <div className="bar-list__track">
                    <span
                      className="bar-list__fill"
                      style={{ width: `${(item.count / maxDept) * 100}%`, background: "#0e7c66" }}
                    />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>

        <SectionCard
          title="Escalation rules"
          description="Trigger hours are measured from the complaint's SLA deadline."
          className="span-12"
          action={
            isAdmin ? (
              <Button variant="outline" size="sm" icon={<Plus size={15} />} onClick={() => setModalOpen(true)}>
                Add rule
              </Button>
            ) : undefined
          }
          bodyClassName="card__body--flush"
        >
          {rules.isLoading ? (
            <div className="table-loading">
              {Array.from({ length: 3 }).map((_, index) => (
                <Skeleton key={index} className="skeleton--row" />
              ))}
            </div>
          ) : rules.error ? (
            <ErrorState
              message={rules.error instanceof Error ? rules.error.message : undefined}
              onRetry={() => rules.refetch()}
            />
          ) : (rules.data ?? []).length === 0 ? (
            <EmptyState
              title="No custom escalation rules"
              description="The engine still escalates overdue complaints using category SLAs. Add a rule to target a specific level or role."
            />
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Level</th>
                    <th>Scope</th>
                    <th>Trigger</th>
                    <th>Target role</th>
                    <th>Created</th>
                    {isAdmin && <th aria-label="Delete" />}
                  </tr>
                </thead>
                <tbody>
                  {(rules.data ?? []).map((rule) => (
                    <tr key={rule.id}>
                      <td>
                        <span className="badge badge--escalated">Level {rule.escalation_level}</span>
                      </td>
                      <td>
                        <div className="cell-title">
                          <strong>
                            {rule.department_id
                              ? departmentMap.get(rule.department_id) ?? "Unknown department"
                              : "All departments"}
                          </strong>
                          <span>
                            {rule.category_id
                              ? categoryMap.get(rule.category_id) ?? "Unknown category"
                              : "All categories"}
                          </span>
                        </div>
                      </td>
                      <td>
                        <span className="inline-priority">
                          <Clock3 size={13} /> {rule.trigger_hours}h
                        </span>
                      </td>
                      <td>
                        <span className="inline-priority">
                          <Users size={13} /> {rule.target_role}
                        </span>
                      </td>
                      <td className="cell-muted">{formatDateTime(rule.created_at)}</td>
                      {isAdmin && (
                        <td>
                          <button
                            type="button"
                            className="icon-button icon-button--danger"
                            aria-label={`Delete rule ${rule.id}`}
                            onClick={() => {
                              if (window.confirm("Delete this escalation rule?")) {
                                deleteRule.mutate(rule.id);
                              }
                            }}
                          >
                            <Trash2 size={15} />
                          </button>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </SectionCard>

        <SectionCard
          title="Escalation history"
          description="Every transition recorded by the engine or a supervisor"
          className="span-12"
          action={
            <Button variant="ghost" size="sm" onClick={() => events.refetch()}>
              Refresh
            </Button>
          }
          bodyClassName="card__body--flush"
        >
          {events.error ? (
            <ErrorState
              message={events.error instanceof Error ? events.error.message : undefined}
              onRetry={() => events.refetch()}
            />
          ) : (events.data ?? []).length === 0 ? (
            <EmptyState
              title="No escalations yet"
              description="When a complaint passes its deadline, the engine records the transition here."
            />
          ) : (
            <ul className="escalation-history">
              {(events.data ?? []).map((event) => (
                <li key={event.id}>
                  <span className="escalation-history__level">
                    L{event.from_level} → L{event.to_level}
                  </span>
                  <div>
                    <strong>
                      {event.complaint_number} · {event.complaint_title}
                    </strong>
                    <p>{event.reason}</p>
                    <span>
                      {event.department ?? "Unassigned"} ·{" "}
                      {event.escalated_to_name
                        ? `assigned to ${event.escalated_to_name}`
                        : "no target officer"}{" "}
                      · {relativeTime(event.created_at)}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>
      </div>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title="Create escalation rule"
        description="Rules add targeted escalation on top of the default SLA breach chain."
        footer={
          <>
            <Button variant="ghost" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button
              loading={createRule.isPending}
              disabled={!ruleForm.trigger_hours || Number(ruleForm.trigger_hours) < 0}
              onClick={() => createRule.mutate()}
            >
              Create rule
            </Button>
          </>
        }
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            createRule.mutate();
          }}
        >
          <div className="form-grid">
            <Field label="Department scope" htmlFor="rule-dept" hint="Leave blank for all departments">
              <Select
                id="rule-dept"
                value={ruleForm.department_id}
                onChange={(event) =>
                  setRuleForm({ ...ruleForm, department_id: event.target.value, category_id: "" })
                }
              >
                <option value="">All departments</option>
                {lookups.departments.map((department) => (
                  <option key={department.id} value={department.id}>
                    {department.name}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Category scope" htmlFor="rule-category" hint="Optional narrowing">
              <Select
                id="rule-category"
                value={ruleForm.category_id}
                onChange={(event) => setRuleForm({ ...ruleForm, category_id: event.target.value })}
              >
                <option value="">All categories</option>
                {filteredCategories.map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.name}
                  </option>
                ))}
              </Select>
            </Field>
          </div>

          <div className="form-grid">
            <Field label="Escalation level" htmlFor="rule-level" required>
              <Select
                id="rule-level"
                value={ruleForm.escalation_level}
                onChange={(event) =>
                  setRuleForm({ ...ruleForm, escalation_level: event.target.value })
                }
              >
                {[1, 2, 3, 4, 5].map((level) => (
                  <option key={level} value={level}>
                    Level {level}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Trigger after (hours)" htmlFor="rule-hours" required>
              <Input
                id="rule-hours"
                type="number"
                min={0}
                max={720}
                value={ruleForm.trigger_hours}
                onChange={(event) => setRuleForm({ ...ruleForm, trigger_hours: event.target.value })}
              />
            </Field>
          </div>

          <Field label="Target role" htmlFor="rule-role" required>
            <Select
              id="rule-role"
              value={ruleForm.target_role}
              onChange={(event) => setRuleForm({ ...ruleForm, target_role: event.target.value })}
            >
              <option value="officer">Officer</option>
              <option value="supervisor">Supervisor</option>
              <option value="admin">Administrator</option>
            </Select>
          </Field>

          <div className="notice notice--info">
            <Clock3 size={16} />
            <span>
              The sweep runs in the background and can be triggered manually at any time. Each
              complaint escalates one level per sweep.
            </span>
          </div>
        </form>
      </Modal>
    </div>
  );
}
