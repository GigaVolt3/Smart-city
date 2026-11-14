import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Bell, ChevronDown, LogOut, Plus, Search, UserRound } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { api } from "../../lib/api";
import { cn, roleMeta } from "../../lib/utils";
import { useAuth } from "../../providers/AuthProvider";
import { Avatar, Button } from "../ui/primitives";
import { BrandMark } from "./BrandMark";

export function Topbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const { data: unread } = useQuery({
    queryKey: ["notifications", "unread"],
    queryFn: () => api.get<{ unread_count: number }>("/notifications/unread-count"),
    refetchInterval: 60_000,
    enabled: Boolean(user),
  });

  useEffect(() => {
    if (!menuOpen) return;
    const handler = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [menuOpen]);

  if (!user) return null;

  return (
    <header className="topbar">
      <div className="topbar__mobile-brand">
        <BrandMark size={26} />
        <span>CivicAI</span>
      </div>

      <form
        className="topbar__search"
        onSubmit={(event) => {
          event.preventDefault();
          navigate(`/complaints${query.trim() ? `?search=${encodeURIComponent(query.trim())}` : ""}`);
        }}
        role="search"
      >
        <Search size={16} aria-hidden />
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search complaint number, title or address"
          aria-label="Search complaints"
        />
        <kbd>/</kbd>
      </form>

      <div className="topbar__actions">
        <Button
          size="sm"
          variant="primary"
          icon={<Plus size={16} />}
          onClick={() => navigate("/complaints/new")}
          className="topbar__new"
        >
          New complaint
        </Button>

        <Link to="/notifications" className="icon-button topbar__bell" aria-label="Notifications">
          <Bell size={18} />
          {(unread?.unread_count ?? 0) > 0 && (
            <span className="topbar__badge">
              {unread && unread.unread_count > 9 ? "9+" : unread?.unread_count}
            </span>
          )}
        </Link>

        <div className="topbar__profile" ref={menuRef}>
          <button
            type="button"
            className="topbar__profile-button"
            onClick={() => setMenuOpen((open) => !open)}
            aria-haspopup="menu"
            aria-expanded={menuOpen}
          >
            <Avatar name={user.full_name} size="sm" />
            <span className="topbar__profile-text">
              <strong>{user.full_name}</strong>
              <small>{roleMeta[user.role]?.label}</small>
            </span>
            <ChevronDown size={15} className={cn(menuOpen && "rotate-180")} />
          </button>

          {menuOpen && (
            <div className="menu" role="menu">
              <div className="menu__header">
                <span>{user.email}</span>
                <small>{user.ward ?? "No ward assigned"}</small>
              </div>
              <Link to="/profile" className="menu__item" onClick={() => setMenuOpen(false)}>
                <UserRound size={16} /> Profile & settings
              </Link>
              <button
                type="button"
                className="menu__item menu__item--danger"
                onClick={() => {
                  setMenuOpen(false);
                  logout();
                  navigate("/login");
                }}
              >
                <LogOut size={16} /> Sign out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
