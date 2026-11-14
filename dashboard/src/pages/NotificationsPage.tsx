import { useState } from "react";
import { Link } from "react-router-dom";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Bell,
  BellRing,
  CheckCheck,
  Check,
  CircleAlert,
  Megaphone,
  Trash2,
  UserCheck,
} from "lucide-react";
import {
  Button,
  EmptyState,
  ErrorState,
  PageHeader,
  Skeleton,
} from "../components/ui/primitives";
import { useNotifications } from "../hooks/queries";
import { useToast } from "../providers/ToastProvider";
import { api } from "../lib/api";
import type { NotificationItem } from "../lib/types";
import { cn, relativeTime } from "../lib/utils";

function iconFor(type: string) {
  switch (type) {
    case "complaint_assigned":
      return <UserCheck size={17} />;
    case "status_changed":
      return <BellRing size={17} />;
    case "escalation":
    case "sla_breach":
      return <CircleAlert size={17} />;
    case "announcement":
      return <Megaphone size={17} />;
    default:
      return <Bell size={17} />;
  }
}

function toneFor(type: string) {
  switch (type) {
    case "escalation":
    case "sla_breach":
      return "danger";
    case "status_changed":
      return "success";
    case "complaint_assigned":
      return "brand";
    default:
      return "neutral";
  }
}

export function NotificationsPage() {
  const [unreadOnly, setUnreadOnly] = useState(false);
  const { notify } = useToast();
  const queryClient = useQueryClient();
  const notifications = useNotifications({ unread_only: unreadOnly, limit: 100 });

  const markRead = useMutation({
    mutationFn: (id: number) => api.put<NotificationItem>(`/notifications/${id}/read`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not mark as read", "error"),
  });

  const markAll = useMutation({
    mutationFn: () => api.post<{ unread_count: number }>("/notifications/read-all"),
    onSuccess: () => {
      notify("All notifications marked as read", "success");
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not update notifications", "error"),
  });

  const remove = useMutation({
    mutationFn: (id: number) => api.delete(`/notifications/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Could not delete notification", "error"),
  });

  const unread = notifications.data?.unread_count ?? 0;

  return (
    <div className="page">
      <PageHeader
        eyebrow="Account"
        title="Notifications"
        description={
          unread > 0
            ? `${unread} unread update${unread === 1 ? "" : "s"} across your complaints and assignments.`
            : "You are up to date. New assignments and status changes appear here."
        }
        actions={
          <Button
            variant="outline"
            size="sm"
            icon={<CheckCheck size={15} />}
            disabled={unread === 0}
            loading={markAll.isPending}
            onClick={() => markAll.mutate()}
          >
            Mark all read
          </Button>
        }
      />

      <div className="notif-toolbar">
        <div className="segmented">
          <button
            type="button"
            className={cn(!unreadOnly && "is-active")}
            onClick={() => setUnreadOnly(false)}
          >
            All
          </button>
          <button
            type="button"
            className={cn(unreadOnly && "is-active")}
            onClick={() => setUnreadOnly(true)}
          >
            Unread {unread > 0 ? `(${unread})` : ""}
          </button>
        </div>
        <span className="notif-toolbar__meta">
          {notifications.data?.total ?? 0} total notifications
        </span>
      </div>

      {notifications.isLoading ? (
        <div className="notif-list">
          {Array.from({ length: 5 }).map((_, index) => (
            <Skeleton key={index} className="skeleton--notif" />
          ))}
        </div>
      ) : notifications.error ? (
        <ErrorState
          message={notifications.error instanceof Error ? notifications.error.message : undefined}
          onRetry={() => notifications.refetch()}
        />
      ) : (notifications.data?.items ?? []).length === 0 ? (
        <div className="card card--padded">
          <EmptyState
            icon={<Bell size={22} />}
            title={unreadOnly ? "No unread notifications" : "Nothing here yet"}
            description={
              unreadOnly
                ? "Every notification has been read. Switch to All to review the archive."
                : "Status changes, assignments and escalation alerts will appear in this inbox."
            }
            action={
              unreadOnly ? (
                <Button variant="outline" size="sm" onClick={() => setUnreadOnly(false)}>
                  Show all notifications
                </Button>
              ) : undefined
            }
          />
        </div>
      ) : (
        <ul className="notif-list">
          {(notifications.data?.items ?? []).map((item) => (
            <li
              key={item.id}
              className={cn("notif-item", !item.is_read && "notif-item--unread")}
            >
              <span className={cn("notif-item__icon", `notif-item__icon--${toneFor(item.notification_type)}`)}>
                {iconFor(item.notification_type)}
              </span>
              <div className="notif-item__body">
                <div className="notif-item__head">
                  <strong>{item.title}</strong>
                  <span>{relativeTime(item.created_at)}</span>
                </div>
                <p>{item.message}</p>
                <div className="notif-item__actions">
                  {item.complaint_id && (
                    <Link to={`/complaints/${item.complaint_id}`} className="text-link">
                      Open complaint
                    </Link>
                  )}
                  <span className="notif-item__type">
                    {item.notification_type.replaceAll("_", " ")}
                  </span>
                </div>
              </div>
              <div className="notif-item__controls">
                {!item.is_read && (
                  <button
                    type="button"
                    className="icon-button"
                    aria-label="Mark as read"
                    onClick={() => markRead.mutate(item.id)}
                  >
                    <Check size={16} />
                  </button>
                )}
                <button
                  type="button"
                  className="icon-button icon-button--danger"
                  aria-label="Delete notification"
                  onClick={() => remove.mutate(item.id)}
                >
                  <Trash2 size={15} />
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
