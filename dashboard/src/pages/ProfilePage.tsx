import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useMutation } from "@tanstack/react-query";
import {
  BadgeCheck,
  Building2,
  Check,
  Eye,
  EyeOff,
  KeyRound,
  LogOut,
  Mail,
  MapPin,
  Phone,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import {
  Avatar,
  Button,
  Card,
  Field,
  Input,
  PageHeader,
  RoleBadge,
  SectionCard,
  Select,
} from "../components/ui/primitives";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { useLookups } from "../hooks/queries";
import { api } from "../lib/api";
import type { User } from "../lib/types";
import { formatDate, roleMeta, WARDS } from "../lib/utils";

const ACCESS_MATRIX: Record<string, string[]> = {
  citizen: [
    "File complaints and attach evidence",
    "Track your own complaints end to end",
    "Receive status and escalation notifications",
    "View the public complaint map",
  ],
  officer: [
    "See complaints assigned to your department",
    "Update status, assignment and resolution notes",
    "Upload resolution evidence and run AI verification",
    "File complaints as a resident",
  ],
  supervisor: [
    "Monitor department SLAs and breaches",
    "Trigger escalation sweeps and manage rules",
    "Review all complaints in your scope",
    "Manage department contact details",
  ],
  admin: [
    "Full municipal access across departments",
    "Manage users, roles and account status",
    "Configure departments, categories and SLAs",
    "Review the immutable audit trail",
  ],
};

export function ProfilePage() {
  const { user, refreshUser, logout } = useAuth();
  const { notify } = useToast();
  const navigate = useNavigate();
  const lookups = useLookups();

  const [profile, setProfile] = useState({
    full_name: user?.full_name ?? "",
    phone_number: user?.phone_number ?? "",
    ward: user?.ward ?? "",
  });
  const [password, setPassword] = useState({
    current_password: "",
    new_password: "",
    confirm_password: "",
  });
  const [showPasswords, setShowPasswords] = useState(false);

  const saveProfile = useMutation({
    mutationFn: () =>
      api.put<User>("/auth/me", {
        full_name: profile.full_name.trim(),
        phone_number: profile.phone_number.trim() || null,
        ward: profile.ward || null,
      }),
    onSuccess: async () => {
      await refreshUser();
      notify("Profile updated", "success");
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not update profile", "error"),
  });

  const changePassword = useMutation({
    mutationFn: () =>
      api.post<{ message: string }>("/auth/change-password", {
        current_password: password.current_password,
        new_password: password.new_password,
      }),
    onSuccess: () => {
      notify("Password changed — use it the next time you sign in", "success");
      setPassword({ current_password: "", new_password: "", confirm_password: "" });
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not change password", "error"),
  });

  if (!user) return null;

  const department = lookups.departments.find((item) => item.id === user.department_id);
  const passwordMismatch =
    password.confirm_password.length > 0 && password.new_password !== password.confirm_password;
  const canChangePassword =
    password.current_password.length > 0 &&
    password.new_password.length >= 8 &&
    password.new_password === password.confirm_password;

  return (
    <div className="page">
      <PageHeader
        eyebrow="Account"
        title="Profile & settings"
        description="Your identity, contact details and security settings for the civic workspace."
      />

      <div className="profile-grid">
        <div className="profile-main">
          <Card className="profile-hero">
            <Avatar name={user.full_name} size="lg" tone="brand" />
            <div className="profile-hero__identity">
              <div className="profile-hero__name">
                <h2>{user.full_name}</h2>
                <RoleBadge role={user.role} />
                {user.is_active && (
                  <span className="badge badge--resolved">
                    <BadgeCheck size={12} /> Active
                  </span>
                )}
              </div>
              <p>{roleMeta[user.role].description}</p>
              <div className="profile-hero__meta">
                <span>
                  <Mail size={14} /> {user.email}
                </span>
                {user.phone_number && (
                  <span>
                    <Phone size={14} /> {user.phone_number}
                  </span>
                )}
                {user.ward && (
                  <span>
                    <MapPin size={14} /> {user.ward}
                  </span>
                )}
                {department && (
                  <span>
                    <Building2 size={14} /> {department.name}
                  </span>
                )}
              </div>
            </div>
            <div className="profile-hero__since">
              <span>Member since</span>
              <strong>{formatDate(user.created_at)}</strong>
            </div>
          </Card>

          <SectionCard
            title="Personal details"
            description="These details appear on complaints you file or action."
          >
            <form
              className="stack"
              onSubmit={(event) => {
                event.preventDefault();
                saveProfile.mutate();
              }}
            >
              <div className="form-grid">
                <Field label="Full name" htmlFor="profile-name" required>
                  <Input
                    id="profile-name"
                    value={profile.full_name}
                    onChange={(event) =>
                      setProfile({ ...profile, full_name: event.target.value })
                    }
                    minLength={2}
                  />
                </Field>
                <Field label="Phone number" htmlFor="profile-phone">
                  <Input
                    id="profile-phone"
                    value={profile.phone_number}
                    onChange={(event) =>
                      setProfile({ ...profile, phone_number: event.target.value })
                    }
                    placeholder="+91 98765 43210"
                  />
                </Field>
              </div>

              <Field label="Ward" htmlFor="profile-ward">
                <Select
                  id="profile-ward"
                  value={profile.ward}
                  onChange={(event) => setProfile({ ...profile, ward: event.target.value })}
                >
                  <option value="">No ward assigned</option>
                  {WARDS.map((ward) => (
                    <option key={ward} value={ward}>
                      {ward}
                    </option>
                  ))}
                </Select>
              </Field>

              <Field
                label="Email address"
                htmlFor="profile-email"
                hint="Email changes are managed by an administrator."
              >
                <Input id="profile-email" value={user.email} disabled />
              </Field>

              <div className="form-actions">
                <Button
                  type="submit"
                  loading={saveProfile.isPending}
                  disabled={profile.full_name.trim().length < 2}
                >
                  Save profile
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() =>
                    setProfile({
                      full_name: user.full_name,
                      phone_number: user.phone_number ?? "",
                      ward: user.ward ?? "",
                    })
                  }
                >
                  Reset
                </Button>
              </div>
            </form>
          </SectionCard>

          <SectionCard
            title="Password & security"
            description="Use a unique password of at least 8 characters."
          >
            <form
              className="stack"
              onSubmit={(event) => {
                event.preventDefault();
                if (canChangePassword) changePassword.mutate();
              }}
            >
              <Field label="Current password" htmlFor="current-password" required>
                <div className="input-with-action">
                  <Input
                    id="current-password"
                    type={showPasswords ? "text" : "password"}
                    value={password.current_password}
                    onChange={(event) =>
                      setPassword({ ...password, current_password: event.target.value })
                    }
                    autoComplete="current-password"
                  />
                  <button
                    type="button"
                    className="input-with-action__button"
                    onClick={() => setShowPasswords((value) => !value)}
                    aria-label={showPasswords ? "Hide passwords" : "Show passwords"}
                  >
                    {showPasswords ? <EyeOff size={17} /> : <Eye size={17} />}
                  </button>
                </div>
              </Field>

              <div className="form-grid">
                <Field
                  label="New password"
                  htmlFor="new-password"
                  hint="Minimum 8 characters"
                  required
                >
                  <Input
                    id="new-password"
                    type={showPasswords ? "text" : "password"}
                    value={password.new_password}
                    onChange={(event) =>
                      setPassword({ ...password, new_password: event.target.value })
                    }
                    autoComplete="new-password"
                  />
                </Field>
                <Field
                  label="Confirm new password"
                  htmlFor="confirm-password"
                  error={passwordMismatch ? "Passwords do not match" : undefined}
                  required
                >
                  <Input
                    id="confirm-password"
                    type={showPasswords ? "text" : "password"}
                    value={password.confirm_password}
                    onChange={(event) =>
                      setPassword({ ...password, confirm_password: event.target.value })
                    }
                    autoComplete="new-password"
                  />
                </Field>
              </div>

              <div className="form-actions">
                <Button
                  type="submit"
                  variant="secondary"
                  icon={<KeyRound size={15} />}
                  loading={changePassword.isPending}
                  disabled={!canChangePassword}
                >
                  Change password
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() =>
                    setPassword({ current_password: "", new_password: "", confirm_password: "" })
                  }
                >
                  Clear
                </Button>
              </div>
            </form>
          </SectionCard>
        </div>

        <aside className="profile-side">
          <Card className="side-card">
            <h2 className="side-card__title">
              <ShieldCheck size={16} /> What you can do
            </h2>
            <ul className="permission-list">
              {(ACCESS_MATRIX[user.role] ?? []).map((item) => (
                <li key={item}>
                  <Check size={14} /> {item}
                </li>
              ))}
            </ul>
            <p className="side-card__note">
              Access is enforced by the API using role and department scoping — not only by the
              interface.
            </p>
          </Card>

          <Card className="side-card">
            <h2 className="side-card__title">
              <UserRound size={16} /> Account facts
            </h2>
            <dl className="side-facts">
              <div>
                <dt>Account ID</dt>
                <dd className="mono">#{user.id}</dd>
              </div>
              <div>
                <dt>Role</dt>
                <dd>{roleMeta[user.role].label}</dd>
              </div>
              <div>
                <dt>Department</dt>
                <dd>{department?.name ?? "Not assigned"}</dd>
              </div>
              <div>
                <dt>Status</dt>
                <dd>{user.is_active ? "Active" : "Suspended"}</dd>
              </div>
              <div>
                <dt>Joined</dt>
                <dd>{formatDate(user.created_at)}</dd>
              </div>
            </dl>
          </Card>

          <Card className="side-card">
            <h2 className="side-card__title">
              <LogOut size={16} /> Session
            </h2>
            <p className="side-card__note">
              Signing out clears the access and refresh tokens stored in this browser. Any unsaved
              form content will be lost.
            </p>
            <Button
              variant="outline"
              size="sm"
              icon={<LogOut size={15} />}
              onClick={() => {
                logout();
                navigate("/login");
              }}
            >
              Sign out of CivicAI
            </Button>
          </Card>
        </aside>
      </div>
    </div>
  );
}
