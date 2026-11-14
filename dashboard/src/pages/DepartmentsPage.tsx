import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Building2,
  Layers,
  Mail,
  Pencil,
  Phone,
  Plus,
  ShieldCheck,
  Users,
} from "lucide-react";
import {
  Button,
  Card,
  ErrorState,
  Field,
  Input,
  PageHeader,
  PageSkeleton,
  Select,
  Textarea,
} from "../components/ui/primitives";
import { Modal } from "../components/ui/Modal";
import { useAnalytics, useLookups } from "../hooks/queries";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { api } from "../lib/api";
import type { Category, Department, Priority } from "../lib/types";
import { cn, formatHours, priorityMeta } from "../lib/utils";

const EMPTY_DEPT = {
  name: "",
  code: "",
  description: "",
  contact_email: "",
  contact_phone: "",
};

const EMPTY_CATEGORY = {
  name: "",
  code: "",
  department_id: "",
  description: "",
  sla_hours: "48",
  priority_default: "medium" as Priority,
  is_active: true,
};

export function DepartmentsPage() {
  const { user } = useAuth();
  const { notify } = useToast();
  const queryClient = useQueryClient();
  const lookups = useLookups();
  const analytics = useAnalytics(30);
  const isAdmin = user?.role === "admin";

  const [tab, setTab] = useState<"departments" | "categories">("departments");
  const [deptModal, setDeptModal] = useState(false);
  const [editingDept, setEditingDept] = useState<Department | null>(null);
  const [deptForm, setDeptForm] = useState(EMPTY_DEPT);
  const [categoryModal, setCategoryModal] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [categoryForm, setCategoryForm] = useState(EMPTY_CATEGORY);

  const performance = useMemo(
    () => new Map((analytics.data?.departments ?? []).map((dept) => [dept.id, dept])),
    [analytics.data],
  );
  const openCreateDept = () => {
    setEditingDept(null);
    setDeptForm(EMPTY_DEPT);
    setDeptModal(true);
  };

  const openEditDept = (department: Department) => {
    setEditingDept(department);
    setDeptForm({
      name: department.name,
      code: department.code,
      description: department.description ?? "",
      contact_email: department.contact_email ?? "",
      contact_phone: department.contact_phone ?? "",
    });
    setDeptModal(true);
  };

  const departmentMutation = useMutation({
    mutationFn: () => {
      const payload = {
        name: deptForm.name.trim(),
        code: deptForm.code.trim().toUpperCase(),
        description: deptForm.description.trim() || null,
        contact_email: deptForm.contact_email.trim() || null,
        contact_phone: deptForm.contact_phone.trim() || null,
      };
      if (editingDept) {
        const { code: _code, ...update } = payload;
        return api.patch<Department>(`/departments/${editingDept.id}`, update);
      }
      return api.post<Department>("/departments", payload);
    },
    onSuccess: () => {
      notify(editingDept ? "Department updated" : "Department created", "success");
      queryClient.invalidateQueries({ queryKey: ["departments"] });
      queryClient.invalidateQueries({ queryKey: ["analytics"] });
      setDeptModal(false);
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not save department", "error"),
  });

  const openCreateCategory = () => {
    setEditingCategory(null);
    setCategoryForm(EMPTY_CATEGORY);
    setCategoryModal(true);
  };

  const openEditCategory = (category: Category) => {
    setEditingCategory(category);
    setCategoryForm({
      name: category.name,
      code: category.code,
      department_id: String(category.department_id),
      description: category.description ?? "",
      sla_hours: String(category.sla_hours),
      priority_default: category.priority_default,
      is_active: category.is_active,
    });
    setCategoryModal(true);
  };

  const categoryMutation = useMutation({
    mutationFn: () => {
      if (editingCategory) {
        return api.patch<Category>(`/categories/${editingCategory.id}`, {
          name: categoryForm.name.trim(),
          description: categoryForm.description.trim() || null,
          sla_hours: Number(categoryForm.sla_hours),
          priority_default: categoryForm.priority_default,
          is_active: categoryForm.is_active,
        });
      }
      return api.post<Category>("/categories", {
        name: categoryForm.name.trim(),
        code: categoryForm.code.trim().toUpperCase(),
        department_id: Number(categoryForm.department_id),
        description: categoryForm.description.trim() || null,
        sla_hours: Number(categoryForm.sla_hours),
        priority_default: categoryForm.priority_default,
        is_active: categoryForm.is_active,
      });
    },
    onSuccess: () => {
      notify(editingCategory ? "Category updated" : "Category created", "success");
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      setCategoryModal(false);
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not save category", "error"),
  });

  if (lookups.isLoading) return <PageSkeleton />;

  if (lookups.error) {
    return (
      <div className="page">
        <ErrorState
          message={lookups.error instanceof Error ? lookups.error.message : undefined}
          onRetry={() => queryClient.invalidateQueries({ queryKey: ["departments"] })}
        />
      </div>
    );
  }

  const { departments, categories } = lookups;
  const categoryCount = (departmentId: number) =>
    categories.filter((category) => category.department_id === departmentId).length;

  return (
    <div className="page">
      <PageHeader
        eyebrow="Municipal structure"
        title="Departments & categories"
        description="Service ownership, contact routing and SLA configuration for each complaint category."
        actions={
          isAdmin &&
          (tab === "departments" ? (
            <Button size="sm" icon={<Plus size={15} />} onClick={openCreateDept}>
              New department
            </Button>
          ) : (
            <Button size="sm" icon={<Plus size={15} />} onClick={openCreateCategory}>
              New category
            </Button>
          ))
        }
      />

      <div className="segmented segmented--wide">
        <button
          type="button"
          className={cn(tab === "departments" && "is-active")}
          onClick={() => setTab("departments")}
        >
          <Building2 size={15} /> Departments ({departments.length})
        </button>
        <button
          type="button"
          className={cn(tab === "categories" && "is-active")}
          onClick={() => setTab("categories")}
        >
          <Layers size={15} /> Categories ({categories.length})
        </button>
      </div>

      {tab === "departments" ? (
        <div className="dept-grid">
          {departments.map((department) => {
            const stats = performance.get(department.id);
            return (
              <Card key={department.id} className="dept-card">
                <div className="dept-card__head">
                  <div className="dept-card__icon">
                    <Building2 size={19} />
                  </div>
                  <div>
                    <h2>{department.name}</h2>
                    <span className="mono">{department.code}</span>
                  </div>
                  {isAdmin && (
                    <button
                      type="button"
                      className="icon-button"
                      aria-label={`Edit ${department.name}`}
                      onClick={() => openEditDept(department)}
                    >
                      <Pencil size={15} />
                    </button>
                  )}
                </div>

                <p className="dept-card__description">
                  {department.description || "No department description recorded."}
                </p>

                <div className="dept-card__contacts">
                  {department.contact_email ? (
                    <a href={`mailto:${department.contact_email}`}>
                      <Mail size={14} /> {department.contact_email}
                    </a>
                  ) : (
                    <span>
                      <Mail size={14} /> No contact email
                    </span>
                  )}
                  {department.contact_phone ? (
                    <a href={`tel:${department.contact_phone}`}>
                      <Phone size={14} /> {department.contact_phone}
                    </a>
                  ) : (
                    <span>
                      <Phone size={14} /> No contact phone
                    </span>
                  )}
                </div>

                <div className="dept-card__stats">
                  <div>
                    <strong>{stats?.total ?? 0}</strong>
                    <span>cases</span>
                  </div>
                  <div>
                    <strong>{stats?.open ?? 0}</strong>
                    <span>open</span>
                  </div>
                  <div>
                    <strong>{stats?.breached ?? 0}</strong>
                    <span>breached</span>
                  </div>
                  <div>
                    <strong>{categoryCount(department.id)}</strong>
                    <span>categories</span>
                  </div>
                </div>

                <div className="dept-card__footer">
                  <span>
                    <ShieldCheck size={14} /> SLA compliance{" "}
                    <strong>{stats ? `${stats.sla_compliance_rate}%` : "—"}</strong>
                  </span>
                  <span>
                    <Users size={14} /> Avg. resolution{" "}
                    <strong>{stats?.avg_resolution_hours ? formatHours(stats.avg_resolution_hours) : "—"}</strong>
                  </span>
                </div>
              </Card>
            );
          })}
          {departments.length === 0 && (
            <Card>
              <div className="empty-state">
                <Building2 size={24} />
                <h3>No departments configured</h3>
                <p>Create a department before categories or complaints can be routed.</p>
              </div>
            </Card>
          )}
        </div>
      ) : (
        <Card padded={false} className="card--flush">
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Department</th>
                  <th>SLA target</th>
                  <th>Default priority</th>
                  <th>Status</th>
                  <th>Code</th>
                  {isAdmin && <th aria-label="Edit" />}
                </tr>
              </thead>
              <tbody>
                {categories.map((category) => {
                  const department = departments.find((item) => item.id === category.department_id);
                  return (
                    <tr key={category.id}>
                      <td>
                        <div className="cell-title">
                          <strong>{category.name}</strong>
                          <span>{category.description || "No description"}</span>
                        </div>
                      </td>
                      <td>{department?.name ?? "—"}</td>
                      <td>
                        <span className="mono">{category.sla_hours}h</span>
                      </td>
                      <td>
                        <span className="inline-priority">
                          <span
                            className="dot"
                            style={{ background: priorityMeta[category.priority_default].dot }}
                          />
                          {priorityMeta[category.priority_default].label}
                        </span>
                      </td>
                      <td>
                        <span
                          className={cn("badge", category.is_active ? "badge--resolved" : "badge--rejected")}
                        >
                          {category.is_active ? "Active" : "Inactive"}
                        </span>
                      </td>
                      <td>
                        <span className="mono cell-muted">{category.code}</span>
                      </td>
                      {isAdmin && (
                        <td>
                          <button
                            type="button"
                            className="icon-button"
                            aria-label={`Edit ${category.name}`}
                            onClick={() => openEditCategory(category)}
                          >
                            <Pencil size={15} />
                          </button>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      <Modal
        open={deptModal}
        onClose={() => setDeptModal(false)}
        title={editingDept ? `Edit ${editingDept.name}` : "Create department"}
        description="Contact details are shown to citizens on complaint tracking."
        footer={
          <>
            <Button variant="ghost" onClick={() => setDeptModal(false)}>
              Cancel
            </Button>
            <Button
              loading={departmentMutation.isPending}
              disabled={!deptForm.name.trim() || (!editingDept && !deptForm.code.trim())}
              onClick={() => departmentMutation.mutate()}
            >
              {editingDept ? "Save changes" : "Create department"}
            </Button>
          </>
        }
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            departmentMutation.mutate();
          }}
        >
          <div className="form-grid">
            <Field label="Department name" htmlFor="dept-name" required>
              <Input
                id="dept-name"
                value={deptForm.name}
                onChange={(event) => setDeptForm({ ...deptForm, name: event.target.value })}
                placeholder="Water Supply Board"
              />
            </Field>
            <Field
              label="Code"
              htmlFor="dept-code"
              hint={editingDept ? "Codes are immutable once created" : "Short unique code"}
              required={!editingDept}
            >
              <Input
                id="dept-code"
                value={deptForm.code}
                disabled={Boolean(editingDept)}
                onChange={(event) => setDeptForm({ ...deptForm, code: event.target.value })}
                placeholder="WSB"
              />
            </Field>
          </div>
          <Field label="Description" htmlFor="dept-desc">
            <Textarea
              id="dept-desc"
              rows={3}
              value={deptForm.description}
              onChange={(event) => setDeptForm({ ...deptForm, description: event.target.value })}
              placeholder="What this department is responsible for…"
              maxLength={255}
            />
          </Field>
          <div className="form-grid">
            <Field label="Contact email" htmlFor="dept-email">
              <Input
                id="dept-email"
                type="email"
                value={deptForm.contact_email}
                onChange={(event) => setDeptForm({ ...deptForm, contact_email: event.target.value })}
                placeholder="desk@municipality.gov.in"
              />
            </Field>
            <Field label="Contact phone" htmlFor="dept-phone">
              <Input
                id="dept-phone"
                value={deptForm.contact_phone}
                onChange={(event) => setDeptForm({ ...deptForm, contact_phone: event.target.value })}
                placeholder="+91 80 2222 0000"
              />
            </Field>
          </div>
        </form>
      </Modal>

      <Modal
        open={categoryModal}
        onClose={() => setCategoryModal(false)}
        title={editingCategory ? `Edit ${editingCategory.name}` : "Create category"}
        description="The SLA target drives deadlines and automatic escalation."
        footer={
          <>
            <Button variant="ghost" onClick={() => setCategoryModal(false)}>
              Cancel
            </Button>
            <Button
              loading={categoryMutation.isPending}
              disabled={
                !categoryForm.name.trim() ||
                (!editingCategory && (!categoryForm.code.trim() || !categoryForm.department_id))
              }
              onClick={() => categoryMutation.mutate()}
            >
              {editingCategory ? "Save changes" : "Create category"}
            </Button>
          </>
        }
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            categoryMutation.mutate();
          }}
        >
          <div className="form-grid">
            <Field label="Category name" htmlFor="cat-name" required>
              <Input
                id="cat-name"
                value={categoryForm.name}
                onChange={(event) => setCategoryForm({ ...categoryForm, name: event.target.value })}
                placeholder="Streetlight failure"
              />
            </Field>
            <Field
              label="Code"
              htmlFor="cat-code"
              hint={editingCategory ? "Codes are immutable" : "Short unique code"}
              required={!editingCategory}
            >
              <Input
                id="cat-code"
                value={categoryForm.code}
                disabled={Boolean(editingCategory)}
                onChange={(event) => setCategoryForm({ ...categoryForm, code: event.target.value })}
                placeholder="LIGHT"
              />
            </Field>
          </div>

          <Field label="Department" htmlFor="cat-dept" required>
            <Select
              id="cat-dept"
              value={categoryForm.department_id}
              disabled={Boolean(editingCategory)}
              onChange={(event) =>
                setCategoryForm({ ...categoryForm, department_id: event.target.value })
              }
            >
              <option value="">Select department</option>
              {departments.map((department) => (
                <option key={department.id} value={department.id}>
                  {department.name}
                </option>
              ))}
            </Select>
          </Field>

          <Field label="Description" htmlFor="cat-desc">
            <Textarea
              id="cat-desc"
              rows={2}
              value={categoryForm.description}
              onChange={(event) =>
                setCategoryForm({ ...categoryForm, description: event.target.value })
              }
              maxLength={255}
            />
          </Field>

          <div className="form-grid">
            <Field label="SLA target (hours)" htmlFor="cat-sla" required>
              <Input
                id="cat-sla"
                type="number"
                min={1}
                max={720}
                value={categoryForm.sla_hours}
                onChange={(event) =>
                  setCategoryForm({ ...categoryForm, sla_hours: event.target.value })
                }
              />
            </Field>
            <Field label="Default priority" htmlFor="cat-priority" required>
              <Select
                id="cat-priority"
                value={categoryForm.priority_default}
                onChange={(event) =>
                  setCategoryForm({
                    ...categoryForm,
                    priority_default: event.target.value as Priority,
                  })
                }
              >
                {Object.entries(priorityMeta)
                  .sort(([, a], [, b]) => b.rank - a.rank)
                  .map(([value, meta]) => (
                    <option key={value} value={value}>
                      {meta.label}
                    </option>
                  ))}
              </Select>
            </Field>
          </div>

          <label className="check-toggle">
            <input
              type="checkbox"
              checked={categoryForm.is_active}
              onChange={(event) =>
                setCategoryForm({ ...categoryForm, is_active: event.target.checked })
              }
            />
            <span>Accepting new complaints</span>
          </label>
        </form>
      </Modal>

      {!isAdmin && (
        <p className="page-fineprint">
          Department and category configuration is restricted to municipal administrators.
        </p>
      )}
    </div>
  );
}
