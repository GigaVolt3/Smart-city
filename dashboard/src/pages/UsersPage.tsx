import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Building2,
  CheckCircle2,
  Mail,
  Pencil,
  Phone,
  Plus,
  Search,
  ShieldCheck,
  UserRound,
  Users,
} from "lucide-react";
import {
  Avatar,
  Button,
  Card,
  ErrorState,
  Field,
  Input,
  PageHeader,
  RoleBadge,
  Select,
  Skeleton,
} from "../components/ui/primitives";
import { Modal } from "../components/ui/Modal";
import { useLookups } from "../hooks/queries";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { api } from "../lib/api";
import type { Role, User } from "../lib/types";
import { cn, formatDate, roleMeta, WARDS } from "../lib/utils";

const EMPTY_USER = {
  full_name: "",
  email: "",
  phone_number: "",
  ward: WARDS[0],
  password: "",
  role: "officer" as Role,
  department_id: "",
  is_active: true,
};

export function UsersPage() {
  const { user: currentUser } = useAuth();
  const { notify } = useToast();
  const queryClient = useQueryClient();
  const lookups = useLookups();
  const isAdmin = currentUser?.role === "admin";

  const [search, setSearch] = useState("");
  const [role, setRole] = useState<"" | Role>("");
  const [departmentId, setDepartmentId] = useState("");
  const [activeOnly, setActiveOnly] = useState(false);

  const users = useQuery({
    queryKey: ["users", "directory", { search, role, departmentId, activeOnly }],
    queryFn: () =>
      api.get<User[]>("/users", {
        search: search.trim() || undefined,
        role: role || undefined,
        department_id: departmentId || undefined,
        is_active: activeOnly ? true : undefined,
      }),
  });

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<User | null>(null);
  const [form, setForm] = useState(EMPTY_USER);
  const [formError, setFormError] = useState<string | null>(null);

  const departmentMap = useMemo(
    () => new Map(lookups.departments.map((department) => [department.id, department])),
    [lookups.departments],
  );

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY_USER);
    setFormError(null);
    setModalOpen(true);
  };

  const openEdit = (target: User) => {
    setEditing(target);
    setForm({
      full_name: target.full_name,
      email: target.email,
      phone_number: target.phone_number ?? "",
      ward: target.ward ?? WARDS[0],
      password: "",
      role: target.role,
      department_id: target.department_id ? String(target.department_id) : "",
      is_active: target.is_active,
    });
    setFormError(null);
    setModalOpen(true);
  };

  const saveUser = useMutation({
    mutationFn: () => {
      if (editing) {
        return api.patch<User>(`/users/${editing.id}`, {
          full_name: form.full_name.trim(),
          phone_number: form.phone_number.trim() || null,
          ward: form.ward || null,
          role: form.role,
          department_id: form.department_id ? Number(form.department_id) : null,
          is_active: form.is_active,
        });
      }
      return api.post<User>("/users", {
        full_name: form.full_name.trim(),
        email: form.email.trim(),
        password: form.password,
        phone_number: form.phone_number.trim() || null,
        ward: form.ward || null,
        role: form.role,
        department_id: form.department_id ? Number(form.department_id) : null,
      });
    },
    onSuccess: () => {
      notify(editing ? "User record updated" : "Staff account created", "success");
      queryClient.invalidateQueries({ queryKey: ["users"] });
      setModalOpen(false);
    },
    onError: (error) => {
      const message = error instanceof Error ? error.message : "Could not save the user";
      setFormError(message);
      notify(message, "error");
    },
  });

  const filteredCount = users.data?.length ?? 0;
  const counts = useMemo(() => {
    const base: Record<string, number> = { total: filteredCount };
    (users.data ?? []).forEach((entry) => {
      base[entry.role] = (base[entry.role] ?? 0) + 1;
    });
    return base;
  }, [users.data, filteredCount]);

  const validationMessage = editing
    ? !form.full_name.trim()
      ? "Full name is required"
      : null
    : !form.full_name.trim()
      ? "Full name is required"
      : !form.email.trim()
        ? "Email is required"
        : form.password.length < 6
          ? "Password must be at least 6 characters"
          : null;

  return (
    <div className="page">
      <PageHeader
        eyebrow="People & access"
        title="Users and roles"
        description="Citizens, field officers, supervisors and administrators who operate the platform."
        actions={
          isAdmin ? (
            <Button size="sm" icon={<Plus size={15} />} onClick={openCreate}>
              Add staff account
            </Button>
          ) : undefined
        }
      />

      <div className="directory-stats">
        <div>
          <Users size={17} />
          <strong>{counts.total ?? 0}</strong>
          <span>people in view</span>
        </div>
        <div>
          <ShieldCheck size={17} />
          <strong>{(counts.officer ?? 0) + (counts.supervisor ?? 0) + (counts.admin ?? 0)}</strong>
          <span>municipal staff</span>
        </div>
        <div>
          <UserRound size={17} />
          <strong>{counts.citizen ?? 0}</strong>
          <span>citizens</span>
        </div>
      </div>

      <section className="filter-bar">
        <div className="filter-bar__top">
          <div className="search-input">
            <Search size={16} aria-hidden />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search by name, email or phone…"
              aria-label="Search users"
            />
          </div>
          <div className="filter-bar__count">{filteredCount} records</div>
        </div>
        <div className="filter-bar__grid">
          <Select
            value={role}
            onChange={(event) => setRole(event.target.value as "" | Role)}
            aria-label="Filter by role"
          >
            <option value="">All roles</option>
            {Object.entries(roleMeta).map(([value, meta]) => (
              <option key={value} value={value}>
                {meta.label}
              </option>
            ))}
          </Select>
          <Select
            value={departmentId}
            onChange={(event) => setDepartmentId(event.target.value)}
            aria-label="Filter by department"
          >
            <option value="">All departments</option>
            {lookups.departments.map((department) => (
              <option key={department.id} value={department.id}>
                {department.name}
              </option>
            ))}
          </Select>
          <label className="check-toggle">
            <input
              type="checkbox"
              checked={activeOnly}
              onChange={(event) => setActiveOnly(event.target.checked)}
            />
            <span>Active only</span>
          </label>
          {isAdmin && (
            <span className="filter-bar__hint">
              <ShieldCheck size={14} /> Admins can change roles and deactivate accounts
            </span>
          )}
        </div>
      </section>

      {users.isLoading || lookups.isLoading ? (
        <Card padded={false} className="card--flush">
          <div className="table-loading">
            {Array.from({ length: 6 }).map((_, index) => (
              <Skeleton key={index} className="skeleton--row" />
            ))}
          </div>
        </Card>
      ) : users.error ? (
        <ErrorState
          message={users.error instanceof Error ? users.error.message : undefined}
          onRetry={() => users.refetch()}
        />
      ) : (users.data ?? []).length === 0 ? (
        <Card>
          <div className="empty-state">
            <Users size={24} />
            <h3>No people match these filters</h3>
            <p>Try clearing the role or department filter, or search a different name.</p>
          </div>
        </Card>
      ) : (
        <>
          <Card padded={false} className="card--flush table-desktop">
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Person</th>
                    <th>Role</th>
                    <th>Department</th>
                    <th>Contact</th>
                    <th>Ward</th>
                    <th>Joined</th>
                    <th>Status</th>
                    {isAdmin && <th aria-label="Edit" />}
                  </tr>
                </thead>
                <tbody>
                  {(users.data ?? []).map((person) => (
                    <tr key={person.id}>
                      <td>
                        <div className="person-cell">
                          <Avatar name={person.full_name} size="sm" />
                          <div className="cell-title">
                            <strong>{person.full_name}</strong>
                            <span>{person.email}</span>
                          </div>
                        </div>
                      </td>
                      <td>
                        <RoleBadge role={person.role} />
                      </td>
                      <td>
                        {person.department_id
                          ? departmentMap.get(person.department_id)?.name ?? "—"
                          : "—"}
                      </td>
                      <td>
                        <div className="contact-stack">
                          <span>
                            <Mail size={12} /> {person.email}
                          </span>
                          <span>
                            <Phone size={12} /> {person.phone_number || "—"}
                          </span>
                        </div>
                      </td>
                      <td>{person.ward ?? "—"}</td>
                      <td className="cell-muted">{formatDate(person.created_at)}</td>
                      <td>
                        <span
                          className={cn(
                            "badge",
                            person.is_active ? "badge--resolved" : "badge--rejected",
                          )}
                        >
                          {person.is_active ? "Active" : "Suspended"}
                        </span>
                      </td>
                      {isAdmin && (
                        <td>
                          <button
                            type="button"
                            className="icon-button"
                            aria-label={`Edit ${person.full_name}`}
                            onClick={() => openEdit(person)}
                          >
                            <Pencil size={15} />
                          </button>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>

          <div className="people-cards cards-mobile">
            {(users.data ?? []).map((person) => (
              <Card key={person.id} className="person-card">
                <div className="person-card__head">
                  <Avatar name={person.full_name} size="md" />
                  <div>
                    <strong>{person.full_name}</strong>
                    <span>{person.email}</span>
                  </div>
                  <RoleBadge role={person.role} />
                </div>
                <dl className="side-facts">
                  <div>
                    <dt>Department</dt>
                    <dd>
                      {person.department_id
                        ? departmentMap.get(person.department_id)?.name ?? "—"
                        : "Unassigned"}
                    </dd>
                  </div>
                  <div>
                    <dt>Ward</dt>
                    <dd>{person.ward ?? "—"}</dd>
                  </div>
                  <div>
                    <dt>Status</dt>
                    <dd>{person.is_active ? "Active" : "Suspended"}</dd>
                  </div>
                </dl>
                {isAdmin && (
                  <Button variant="outline" size="sm" onClick={() => openEdit(person)}>
                    Manage access
                  </Button>
                )}
              </Card>
            ))}
          </div>
        </>
      )}

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? `Manage ${editing.full_name}` : "Create a staff account"}
        description={
          editing
            ? "Role and department determine which complaints this person can see and action."
            : "Staff can sign in immediately with the password you set."
        }
        footer={
          <>
            <Button variant="ghost" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button
              loading={saveUser.isPending}
              disabled={Boolean(validationMessage)}
              onClick={() => saveUser.mutate()}
            >
              {editing ? "Save changes" : "Create account"}
            </Button>
          </>
        }
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            if (!validationMessage) saveUser.mutate();
          }}
        >
          {formError && <div className="alert alert--error">{formError}</div>}

          <div className="form-grid">
            <Field label="Full name" htmlFor="user-name" required>
              <Input
                id="user-name"
                value={form.full_name}
                onChange={(event) => setForm({ ...form, full_name: event.target.value })}
                placeholder="Officer name"
              />
            </Field>
            <Field label="Phone number" htmlFor="user-phone">
              <Input
                id="user-phone"
                value={form.phone_number}
                onChange={(event) => setForm({ ...form, phone_number: event.target.value })}
                placeholder="+91 98765 43210"
              />
            </Field>
          </div>

          {!editing && (
            <div className="form-grid">
              <Field label="Email address" htmlFor="user-email" required>
                <Input
                  id="user-email"
                  type="email"
                  value={form.email}
                  onChange={(event) => setForm({ ...form, email: event.target.value })}
                  placeholder="name@municipality.gov.in"
                />
              </Field>
              <Field
                label="Initial password"
                htmlFor="user-password"
                hint="Minimum 6 characters"
                required
              >
                <Input
                  id="user-password"
                  type="password"
                  value={form.password}
                  onChange={(event) => setForm({ ...form, password: event.target.value })}
                  autoComplete="new-password"
                />
              </Field>
            </div>
          )}

          <div className="form-grid">
            <Field label="Role" htmlFor="user-role" required>
              <Select
                id="user-role"
                value={form.role}
                onChange={(event) => setForm({ ...form, role: event.target.value as Role })}
              >
                {Object.entries(roleMeta).map(([value, meta]) => (
                  <option key={value} value={value}>
                    {meta.label}
                  </option>
                ))}
              </Select>
            </Field>
            <Field
              label="Department"
              htmlFor="user-dept"
              hint={form.role === "citizen" ? "Not used for citizens" : "Required for field staff"}
            >
              <Select
                id="user-dept"
                value={form.department_id}
                onChange={(event) => setForm({ ...form, department_id: event.target.value })}
                disabled={form.role === "citizen"}
              >
                <option value="">Unassigned</option>
                {lookups.departments.map((department) => (
                  <option key={department.id} value={department.id}>
                    {department.name}
                  </option>
                ))}
              </Select>
            </Field>
          </div>

          <Field label="Ward" htmlFor="user-ward">
            <Select
              id="user-ward"
              value={form.ward}
              onChange={(event) => setForm({ ...form, ward: event.target.value })}
            >
              {WARDS.map((ward) => (
                <option key={ward} value={ward}>
                  {ward}
                </option>
              ))}
            </Select>
          </Field>

          {editing && (
            <label className="check-toggle">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(event) => setForm({ ...form, is_active: event.target.checked })}
              />
              <span>Account is active and can sign in</span>
            </label>
          )}

          <div className="notice notice--info">
            <Building2 size={16} />
            <span>
              {roleMeta[form.role].description}. Department scoping applies to officers and
              supervisors.
            </span>
          </div>

          {editing && editing.id === currentUser?.id && (
            <div className="notice notice--warning">
              <CheckCircle2 size={16} />
              <span>You cannot deactivate your own administrator account.</span>
            </div>
          )}
        </form>
      </Modal>
    </div>
  );
}
