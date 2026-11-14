import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../../providers/AuthProvider";
import { Spinner } from "../ui/primitives";
import { MobileNav } from "./MobileNav";
import { Sidebar } from "./Sidebar";
import { Topbar } from "./Topbar";
import type { Role } from "../../lib/types";

export function RequireAuth({ children }: { children?: React.ReactNode }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="boot-screen">
        <Spinner label="Loading CivicAI" />
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <>{children ?? <Outlet />}</>;
}

export function RequireRole({ roles, children }: { roles: Role[]; children: React.ReactNode }) {
  const { user } = useAuth();
  if (!user) return null;
  if (!roles.includes(user.role)) return <Navigate to="/" replace />;
  return <>{children}</>;
}

export function AppShell() {
  return (
    <div className="app-shell">
      <a href="#main-content" className="skip-link">
        Skip to content
      </a>
      <Sidebar />
      <div className="app-shell__main">
        <Topbar />
        <main id="main-content" className="app-shell__content">
          <Outlet />
        </main>
      </div>
      <MobileNav />
    </div>
  );
}
