import type { ReactNode } from "react";
import { ArrowDownRight, ArrowUpRight } from "lucide-react";
import { cn } from "../../lib/utils";

export function StatCard({
  label,
  value,
  hint,
  icon,
  tone = "neutral",
  trend,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  icon: ReactNode;
  tone?: "neutral" | "brand" | "warn" | "danger" | "success";
  trend?: { value: number; label: string };
}) {
  return (
    <article className={cn("stat-card", `stat-card--${tone}`)}>
      <div className="stat-card__top">
        <span className="stat-card__icon">{icon}</span>
        {trend && (
          <span className={cn("stat-card__trend", trend.value >= 0 ? "is-up" : "is-down")}>
            {trend.value >= 0 ? <ArrowUpRight size={13} /> : <ArrowDownRight size={13} />}
            {Math.abs(trend.value)}%
          </span>
        )}
      </div>
      <p className="stat-card__label">{label}</p>
      <p className="stat-card__value">{value}</p>
      {hint && <p className="stat-card__hint">{hint}</p>}
    </article>
  );
}
