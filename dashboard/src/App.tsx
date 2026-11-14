import { useEffect } from "react";
import { BrowserRouter, Navigate, Route, Routes, useLocation } from "react-router-dom";
import { AppShell, RequireAuth, RequireRole } from "./components/layout/AppShell";
import { AuthProvider } from "./providers/AuthProvider";
import { ToastProvider } from "./providers/ToastProvider";
import { DashboardPage } from "./pages/DashboardPage";
import { ComplaintsPage } from "./pages/ComplaintsPage";
import { ComplaintDetailPage } from "./pages/ComplaintDetailPage";
import { NewComplaintPage } from "./pages/NewComplaintPage";
import { MapPage } from "./pages/MapPage";
import { AnalyticsPage } from "./pages/AnalyticsPage";
import { DepartmentsPage } from "./pages/DepartmentsPage";
import { UsersPage } from "./pages/UsersPage";
import { NotificationsPage } from "./pages/NotificationsPage";
import { ProfilePage } from "./pages/ProfilePage";
import { EscalationsPage } from "./pages/EscalationsPage";
import { AuditPage } from "./pages/AuditPage";
import { LoginPage } from "./pages/LoginPage";
import { RegisterPage } from "./pages/RegisterPage";
import { NotFoundPage } from "./pages/NotFoundPage";

function ScrollToTop() {
  const location = useLocation();
  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "instant" });
  }, [location.pathname]);
  return null;
}

export default function App() {
  return (
    <BrowserRouter>
      <ScrollToTop />
      <ToastProvider>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />

            <Route element={<RequireAuth />}>
              <Route element={<AppShell />}>
                <Route index element={<DashboardPage />} />
                <Route path="complaints" element={<ComplaintsPage />} />
                <Route path="complaints/new" element={<NewComplaintPage />} />
                <Route path="complaints/:id" element={<ComplaintDetailPage />} />
                <Route path="map" element={<MapPage />} />
                <Route
                  path="analytics"
                  element={
                    <RequireRole roles={["officer", "supervisor", "admin"]}>
                      <AnalyticsPage />
                    </RequireRole>
                  }
                />
                <Route
                  path="escalations"
                  element={
                    <RequireRole roles={["supervisor", "admin"]}>
                      <EscalationsPage />
                    </RequireRole>
                  }
                />
                <Route
                  path="departments"
                  element={
                    <RequireRole roles={["supervisor", "admin"]}>
                      <DepartmentsPage />
                    </RequireRole>
                  }
                />
                <Route
                  path="users"
                  element={
                    <RequireRole roles={["supervisor", "admin"]}>
                      <UsersPage />
                    </RequireRole>
                  }
                />
                <Route
                  path="audit"
                  element={
                    <RequireRole roles={["admin"]}>
                      <AuditPage />
                    </RequireRole>
                  }
                />
                <Route path="notifications" element={<NotificationsPage />} />
                <Route path="profile" element={<ProfilePage />} />
                <Route path="*" element={<NotFoundPage />} />
              </Route>
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  );
}
