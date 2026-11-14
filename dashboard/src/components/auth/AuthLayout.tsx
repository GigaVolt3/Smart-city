import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { ShieldCheck, Sparkles, Waypoints } from "lucide-react";
import { BrandMark } from "../../components/layout/BrandMark";

export function AuthLayout({
  children,
  footer,
}: {
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="auth">
      <aside className="auth__brand">
        <div className="auth__brand-inner">
          <Link to="/" className="auth__logo">
            <BrandMark size={36} />
            <div>
              <strong>CivicAI</strong>
              <span>Municipal operations platform</span>
            </div>
          </Link>

          <div className="auth__pitch">
            <p className="auth__eyebrow">Smart governance, in one place</p>
            <h1>
              Every civic complaint,
              <br />
              routed, tracked and resolved.
            </h1>
            <p>
              A single operational picture for citizens, field officers and municipal
              leadership — from the first report to verified resolution.
            </p>
          </div>

          <ol className="auth__flow">
            <li>
              <span className="auth__flow-icon">
                <Waypoints size={17} />
              </span>
              <div>
                <strong>AI triage in seconds</strong>
                <p>Complaints are classified, deduplicated and priority-scored automatically.</p>
              </div>
            </li>
            <li>
              <span className="auth__flow-icon">
                <ShieldCheck size={17} />
              </span>
              <div>
                <strong>SLA-bound accountability</strong>
                <p>Deadlines are enforced through a transparent escalation chain.</p>
              </div>
            </li>
            <li>
              <span className="auth__flow-icon">
                <Sparkles size={17} />
              </span>
              <div>
                <strong>Verified resolution</strong>
                <p>Before-and-after evidence checks confirm that work was actually completed.</p>
              </div>
            </li>
          </ol>

          <p className="auth__fineprint">
            Demonstration deployment for Bengaluru wards · All records are synthetic
          </p>
        </div>
      </aside>

      <main className="auth__panel">
        <div className="auth__card">
          <Link to="/" className="auth__mobile-logo">
            <BrandMark size={28} /> CivicAI
          </Link>
          {children}
          {footer}
        </div>
      </main>
    </div>
  );
}
