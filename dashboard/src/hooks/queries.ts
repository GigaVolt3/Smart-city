import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import type {
  AnalyticsOverview,
  Category,
  Complaint,
  ComplaintDetail,
  ComplaintPage,
  Department,
  NotificationList,
  User,
} from "../lib/types";

export function useAnalytics(days = 30) {
  return useQuery({
    queryKey: ["analytics", days],
    queryFn: () => api.get<AnalyticsOverview>("/analytics/overview", { days }),
    staleTime: 30_000,
  });
}

export function useLookups() {
  const departments = useQuery({
    queryKey: ["departments"],
    queryFn: () => api.get<Department[]>("/departments"),
    staleTime: 5 * 60_000,
  });
  const categories = useQuery({
    queryKey: ["categories"],
    queryFn: () => api.get<Category[]>("/categories"),
    staleTime: 5 * 60_000,
  });

  return {
    departments: departments.data ?? [],
    categories: categories.data ?? [],
    isLoading: departments.isLoading || categories.isLoading,
    error: departments.error ?? categories.error,
    refetch: () => {
      void departments.refetch();
      void categories.refetch();
    },
  };
}

export type ComplaintFilters = {
  search?: string;
  status?: string;
  priority?: string;
  department_id?: number | string;
  category_id?: number | string;
  ward?: string;
  assigned_to_me?: boolean;
  overdue?: boolean;
  skip?: number;
  limit?: number;
};

export function useComplaintPage(filters: ComplaintFilters) {
  return useQuery({
    queryKey: ["complaints", "page", filters],
    queryFn: () => api.get<ComplaintPage>("/complaints/paged", filters),
    placeholderData: (previous) => previous,
  });
}

export function useComplaints(filters: ComplaintFilters = {}, enabled = true) {
  return useQuery({
    queryKey: ["complaints", "list", filters],
    queryFn: () => api.get<Complaint[]>("/complaints", filters),
    enabled,
  });
}

export function useComplaint(id?: number | string) {
  return useQuery({
    queryKey: ["complaint", id],
    queryFn: () => api.get<ComplaintDetail>(`/complaints/${id}`),
    enabled: Boolean(id),
  });
}

export function useNotifications(params: { unread_only?: boolean; limit?: number } = {}) {
  return useQuery({
    queryKey: ["notifications", "list", params],
    queryFn: () => api.get<NotificationList>("/notifications", params),
    refetchInterval: 60_000,
  });
}

export function useUsers(params: {
  role?: string;
  department_id?: number | string;
  search?: string;
  is_active?: boolean;
} = {}) {
  return useQuery({
    queryKey: ["users", params],
    queryFn: () => api.get<User[]>("/users", params),
  });
}
