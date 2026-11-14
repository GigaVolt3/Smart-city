import clsx, { type ClassValue } from "clsx";
import type { ComplaintStatus, Priority, Role } from "./types";

export function cn(...values: ClassValue[]): string {
  return clsx(values);
}

export function parseApiDate(value?: string | null): Date | null {
  if (!value) return null;
  const normalised = /Z$|[+-]\d{2}:\d{2}$/.test(value) ? value : `${value}Z`;
  const date = new Date(normalised);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function formatDate(value?: string | null): string {
  const date = parseApiDate(value);
  if (!date) return "—";
  return date.toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export function formatDateTime(value?: string | null): string {
  const date = parseApiDate(value);
  if (!date) return "—";
  return date.toLocaleString("en-IN", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function relativeTime(value?: string | null): string {
  const date = parseApiDate(value);
  if (!date) return "—";
  const diffSeconds = Math.round((date.getTime() - Date.now()) / 1000);
  const units: Array<[Intl.RelativeTimeFormatUnit, number]> = [
    ["year", 60 * 60 * 24 * 365],
    ["month", 60 * 60 * 24 * 30],
    ["day", 60 * 60 * 24],
    ["hour", 60 * 60],
    ["minute", 60],
  ];
  const formatter = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  for (const [unit, seconds] of units) {
    if (Math.abs(diffSeconds) >= seconds) {
      return formatter.format(Math.round(diffSeconds / seconds), unit);
    }
  }
  return "just now";
}

export function initials(name?: string | null): string {
  if (!name) return "?";
  return name
    .replace(/\(.*?\)/g, "")
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join("");
}

export function formatHours(hours: number): string {
  if (!hours) return "—";
  if (hours < 24) return `${hours.toFixed(hours < 10 ? 1 : 0)}h`;
  const days = hours / 24;
  return `${days.toFixed(days < 10 ? 1 : 0)}d`;
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export type SlaState = "breached" | "at_risk" | "on_track" | "met" | "closed";

export function slaState(
  dueAt: string,
  status: ComplaintStatus,
): { state: SlaState; label: string } {
  const due = parseApiDate(dueAt);
  if (!due) return { state: "on_track", label: "No deadline" };
  const now = Date.now();
  const diff = due.getTime() - now;
  const hours = diff / 3_600_000;

  if (status === "resolved") {
    return { state: "met", label: "Resolved" };
  }
  if (status === "rejected") {
    return { state: "closed", label: "Rejected" };
  }
  if (diff < 0) {
    return { state: "breached", label: `Overdue ${formatHours(Math.abs(hours))}` };
  }
  if (hours <= 24) {
    return { state: "at_risk", label: `${formatHours(hours)} left` };
  }
  return { state: "on_track", label: `${formatHours(hours)} left` };
}

export const statusMeta: Record<
  ComplaintStatus,
  { label: string; className: string; dot: string }
> = {
  submitted: { label: "Submitted", className: "badge--submitted", dot: "#3b82f6" },
  assigned: { label: "Assigned", className: "badge--assigned", dot: "#8b5cf6" },
  in_progress: { label: "In progress", className: "badge--progress", dot: "#d97706" },
  escalated: { label: "Escalated", className: "badge--escalated", dot: "#dc2626" },
  resolved: { label: "Resolved", className: "badge--resolved", dot: "#059669" },
  rejected: { label: "Rejected", className: "badge--rejected", dot: "#64748b" },
};

export const priorityMeta: Record<
  Priority,
  { label: string; className: string; dot: string; rank: number }
> = {
  critical: { label: "Critical", className: "badge--critical", dot: "#dc2626", rank: 4 },
  high: { label: "High", className: "badge--high", dot: "#ea580c", rank: 3 },
  medium: { label: "Medium", className: "badge--medium", dot: "#d97706", rank: 2 },
  low: { label: "Low", className: "badge--low", dot: "#64748b", rank: 1 },
};

export const roleMeta: Record<Role, { label: string; description: string }> = {
  citizen: { label: "Citizen", description: "Files and tracks grievances" },
  officer: { label: "Officer", description: "Resolves department complaints" },
  supervisor: { label: "Supervisor", description: "Monitors SLAs and escalations" },
  admin: { label: "Administrator", description: "Full municipal control" },
};

export const WARDS = [
  "Ward 1 (Malleshwaram)",
  "Ward 3 (Rajajinagar)",
  "Ward 5 (Jayanagar)",
  "Ward 8 (Koramangala)",
  "Ward 9 (BTM Layout)",
  "Ward 12 (Indiranagar)",
  "Ward 14 (Hebbal)",
  "Ward 15 (Domlur)",
  "Ward 18 (Whitefield)",
  "Ward 22 (HSR Layout)",
];

export function plural(count: number, singular: string, pluralForm?: string): string {
  return count === 1 ? singular : pluralForm ?? `${singular}s`;
}

export function downloadCsv(filename: string, rows: Array<Record<string, unknown>>) {
  if (!rows.length) return;
  const headers = Object.keys(rows[0]);
  const escape = (value: unknown) => {
    const text = value === null || value === undefined ? "" : String(value);
    return `"${text.replace(/"/g, '""')}"`;
  };
  const csv = [
    headers.join(","),
    ...rows.map((row) => headers.map((header) => escape(row[header])).join(",")),
  ].join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}
