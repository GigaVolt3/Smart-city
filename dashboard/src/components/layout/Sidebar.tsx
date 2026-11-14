import {
  ArrowUpRight,
  Bell,
  Building2,
  ChartNoAxesCombined,
  ClipboardList,
  LayoutDashboard,
  Map,
  ScrollText,
  Settings2,
  Users,
} from "lucide-react";
import { NavLink } from "react-router-dom";
import { useAuth } from "../../providers/AuthProvider";
import type { Role } from "../../lib/types";
import { cn, roleMeta } from "../../lib/utils";
import { Avatar } from "../ui/primitives";

type NavItem = {
  to: string;
  label: string;
  icon: typeof LayoutDashboard;
  roles?: Role[];
  end?: boolean;
};

const operations: NavItem[] = [
  { to: "/", label: "Overview", icon: LayoutDashboard, end: true },
  { to: "/complaints", label: "Complaints", icon: ClipboardList },
  { to: "/map", label: "Live map", icon: Map },
  {
    to: "/analytics",
    label: "Analytics",
    icon: ChartNoAxesCombined,
    roles: ["officer", "supervisor", "admin"],
  },
];

const administration: NavItem[] = [
  {
    to: "/escalations",
    label: "Escalations",
    icon: ArrowUpRight,
    roles: ["supervisor", "admin"],
  },
  {
    to: "/departments",
    label: "Departments",
    icon: Building2,
    roles: ["supervisor", "admin"],
  },
  {
    to: "/users",
    label: "People & roles",
    icon: Users,
    roles: ["supervisor", "admin"],
  },
  { to: "/audit", label: "Audit trail", icon: ScrollText, roles: ["admin"] },
];

const account: NavItem[] = [
  { to: "/notifications", label: "Notifications", icon: Bell },
  { to: "/profile", label: "Profile & settings", icon: Settings2 },
];

function canSee(item: NavItem, role: Role) {
  return !item.roles || item.roles.includes(role);
}

function NavSection({
  label,
  items,
  role,
}: {
  label: string;
  items: NavItem[];
  role: Role;
}) {
  const visible = items.filter((item) => canSee(item, role));
  if (!visible.length) return null;

  return (
    <div className="sidebar__section">
      <p className="sidebar__label">{label}</p>
      <nav className="sidebar__nav">
        {visible.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) =>
              cn("sidebar__link", isActive && "sidebar__link--active")
            }
          >
            <item.icon size={17} strokeWidth={1.9} />
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

export function Sidebar() {
  const { user } = useAuth();
  if (!user) return null;

  return (
    <aside className="sidebar">
      <div className="sidebar__brand">
        <div className="sidebar__brand-text">
          <span className="sidebar__wordmark">CivicAI</span>
          <span className="sidebar__tagline">Municipal operations</span>
        </div>
      </div>

      <div className="sidebar__scroll">
        <NavSection label="Operations" items={operations} role={user.role} />
        <NavSection label="Administration" items={administration} role={user.role} />
        <NavSection label="Account" items={account} role={user.role} />
      </div>

      <div className="sidebar__footer">
        <NavLink to="/profile" className="sidebar__user">
          <Avatar name={user.full_name} size="sm" tone="brand" />
          <span className="sidebar__user-text">
            <strong>{user.full_name}</strong>
            <small>{roleMeta[user.role]?.label}</small>
          </span>
        </NavLink>
      </div>
    </aside>
  );
}
