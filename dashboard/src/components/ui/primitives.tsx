import {
  forwardRef,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from "react";
import {
  AlertCircle,
  ChevronLeft,
  ChevronRight,
  Inbox,
  LoaderCircle,
  Search,
} from "lucide-react";
import { cn, initials, priorityMeta, roleMeta, statusMeta } from "../../lib/utils";
import type { ComplaintStatus, Priority, Role } from "../../lib/types";

/* -------------------------------------------------------------------------- */
/* Buttons                                                                    */
/* -------------------------------------------------------------------------- */

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger" | "outline";
type ButtonSize = "sm" | "md" | "lg" | "icon";

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
  icon?: ReactNode;
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { className, variant = "primary", size = "md", loading, icon, children, disabled, ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      className={cn("btn", `btn--${variant}`, `btn--${size}`, className)}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? <LoaderCircle size={16} className="spin" /> : icon}
      {children}
    </button>
  );
});

/* -------------------------------------------------------------------------- */
/* Form controls                                                              */
/* -------------------------------------------------------------------------- */

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className, ...props }, ref) {
    return <input ref={ref} className={cn("input", className)} {...props} />;
  },
);

export const Textarea = forwardRef<
  HTMLTextAreaElement,
  TextareaHTMLAttributes<HTMLTextAreaElement>
>(function Textarea({ className, ...props }, ref) {
  return <textarea ref={ref} className={cn("input", "textarea", className)} {...props} />;
});

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  function Select({ className, children, ...props }, ref) {
    return (
      <select ref={ref} className={cn("input", "select", className)} {...props}>
        {children}
      </select>
    );
  },
);

export function Field({
  label,
  htmlFor,
  hint,
  error,
  required,
  children,
  className,
}: {
  label: string;
  htmlFor?: string;
  hint?: string;
  error?: string;
  required?: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("field", className)}>
      <label className="field__label" htmlFor={htmlFor}>
        {label}
        {required && <span className="field__required">*</span>}
      </label>
      {children}
      {error ? (
        <p className="field__error">{error}</p>
      ) : hint ? (
        <p className="field__hint">{hint}</p>
      ) : null}
    </div>
  );
}

export const SearchInput = forwardRef<
  HTMLInputElement,
  InputHTMLAttributes<HTMLInputElement>
>(function SearchInput({ className, ...props }, ref) {
  return (
    <div className={cn("search-input", className)}>
      <Search size={16} aria-hidden />
      <input ref={ref} {...props} />
    </div>
  );
});

/* -------------------------------------------------------------------------- */
/* Badges                                                                     */
/* -------------------------------------------------------------------------- */

export function StatusBadge({ status }: { status: ComplaintStatus }) {
  const meta = statusMeta[status] ?? statusMeta.submitted;
  return (
    <span className={cn("badge", meta.className)}>
      <span className="badge__dot" style={{ backgroundColor: meta.dot }} />
      {meta.label}
    </span>
  );
}

export function PriorityBadge({ priority }: { priority: Priority }) {
  const meta = priorityMeta[priority] ?? priorityMeta.medium;
  return (
    <span className={cn("badge", meta.className)}>
      <span className="badge__dot" style={{ backgroundColor: meta.dot }} />
      {meta.label}
    </span>
  );
}

export function RoleBadge({ role }: { role: Role }) {
  return <span className={cn("badge", `badge--role-${role}`)}>{roleMeta[role]?.label ?? role}</span>;
}

/* -------------------------------------------------------------------------- */
/* Surfaces                                                                   */
/* -------------------------------------------------------------------------- */

export function Card({
  children,
  className,
  padded = true,
}: {
  children: ReactNode;
  className?: string;
  padded?: boolean;
}) {
  return <section className={cn("card", padded && "card--padded", className)}>{children}</section>;
}

export function SectionCard({
  title,
  description,
  action,
  children,
  className,
  bodyClassName,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
}) {
  return (
    <section className={cn("card", className)}>
      <header className="card__header">
        <div>
          <h2 className="card__title">{title}</h2>
          {description && <p className="card__description">{description}</p>}
        </div>
        {action && <div className="card__action">{action}</div>}
      </header>
      <div className={cn("card__body", bodyClassName)}>{children}</div>
    </section>
  );
}

export function PageHeader({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="page-header">
      <div className="page-header__text">
        {eyebrow && <p className="page-header__eyebrow">{eyebrow}</p>}
        <h1 className="page-header__title">{title}</h1>
        {description && <p className="page-header__description">{description}</p>}
      </div>
      {actions && <div className="page-header__actions">{actions}</div>}
    </header>
  );
}

export function Avatar({
  name,
  size = "md",
  tone,
}: {
  name?: string | null;
  size?: "sm" | "md" | "lg";
  tone?: "brand" | "warm";
}) {
  return (
    <span className={cn("avatar", `avatar--${size}`, tone && `avatar--${tone}`)}>
      {initials(name)}
    </span>
  );
}

/* -------------------------------------------------------------------------- */
/* States                                                                     */
/* -------------------------------------------------------------------------- */

export function Spinner({ label }: { label?: string }) {
  return (
    <div className="spinner" role="status">
      <LoaderCircle size={22} className="spin" />
      {label && <span>{label}</span>}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("skeleton", className)} aria-hidden />;
}

export function PageSkeleton() {
  return (
    <div className="page">
      <Skeleton className="skeleton--title" />
      <div className="kpi-grid">
        {[0, 1, 2, 3].map((index) => (
          <Skeleton key={index} className="skeleton--card" />
        ))}
      </div>
      <div className="grid grid--2-1">
        <Skeleton className="skeleton--panel" />
        <Skeleton className="skeleton--panel" />
      </div>
    </div>
  );
}

export function EmptyState({
  title,
  description,
  action,
  icon,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  icon?: ReactNode;
}) {
  return (
    <div className="empty-state">
      <div className="empty-state__icon">{icon ?? <Inbox size={22} />}</div>
      <h3>{title}</h3>
      {description && <p>{description}</p>}
      {action}
    </div>
  );
}

export function ErrorState({
  message,
  onRetry,
}: {
  message?: string;
  onRetry?: () => void;
}) {
  return (
    <div className="empty-state empty-state--error">
      <div className="empty-state__icon">
        <AlertCircle size={22} />
      </div>
      <h3>Something went wrong</h3>
      <p>{message ?? "The request could not be completed. Please try again."}</p>
      {onRetry && (
        <Button variant="outline" size="sm" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* Pagination                                                                 */
/* -------------------------------------------------------------------------- */

export function Pagination({
  page,
  pageSize,
  total,
  onPageChange,
}: {
  page: number;
  pageSize: number;
  total: number;
  onPageChange: (page: number) => void;
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const start = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const end = Math.min(total, page * pageSize);

  return (
    <div className="pagination">
      <p>
        Showing <strong>{start}–{end}</strong> of <strong>{total}</strong>
      </p>
      <div className="pagination__controls">
        <Button
          variant="outline"
          size="sm"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          aria-label="Previous page"
          icon={<ChevronLeft size={15} />}
        >
          Prev
        </Button>
        <span className="pagination__page">
          {page} / {pages}
        </span>
        <Button
          variant="outline"
          size="sm"
          disabled={page >= pages}
          onClick={() => onPageChange(page + 1)}
          aria-label="Next page"
        >
          Next
          <ChevronRight size={15} />
        </Button>
      </div>
    </div>
  );
}
