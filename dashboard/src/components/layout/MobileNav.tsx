import { Bell, ClipboardList, Home, Map, Plus } from "lucide-react";
import { NavLink, useLocation } from "react-router-dom";
import { cn } from "../../lib/utils";

const items = [
  { to: "/", label: "Home", icon: Home, end: true },
  { to: "/complaints", label: "Cases", icon: ClipboardList },
  { to: "/map", label: "Map", icon: Map },
  { to: "/notifications", label: "Alerts", icon: Bell },
];

export function MobileNav() {
  const location = useLocation();
  const isNew = location.pathname === "/complaints/new";

  return (
    <nav className="mobile-nav" aria-label="Primary">
      {items.slice(0, 2).map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          end={item.end}
          className={({ isActive }) =>
            cn("mobile-nav__item", isActive && "mobile-nav__item--active")
          }
        >
          <item.icon size={20} strokeWidth={1.9} />
          <span>{item.label}</span>
        </NavLink>
      ))}

      <NavLink
        to="/complaints/new"
        className={cn("mobile-nav__fab", isNew && "mobile-nav__fab--active")}
        aria-label="Report a new complaint"
      >
        <Plus size={23} />
      </NavLink>

      {items.slice(2).map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) =>
            cn("mobile-nav__item", isActive && "mobile-nav__item--active")
          }
        >
          <item.icon size={20} strokeWidth={1.9} />
          <span>{item.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
