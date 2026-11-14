const ACCESS_KEY = "civicai.access_token";
const REFRESH_KEY = "civicai.refresh_token";

const API_BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? "/api/v1";
const ASSET_ORIGIN = (import.meta.env.VITE_ASSET_ORIGIN as string | undefined) ?? "";

export class ApiError extends Error {
  status: number;
  detail: string;
  payload: unknown;

  constructor(status: number, detail: string, payload?: unknown) {
    super(detail);
    this.name = "ApiError";
    this.status = status;
    this.detail = detail;
    this.payload = payload;
  }
}

export const tokenStore = {
  get access() {
    return localStorage.getItem(ACCESS_KEY);
  },
  get refresh() {
    return localStorage.getItem(REFRESH_KEY);
  },
  set(access: string, refresh: string) {
    localStorage.setItem(ACCESS_KEY, access);
    localStorage.setItem(REFRESH_KEY, refresh);
  },
  clear() {
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
  },
};

export function assetUrl(path?: string | null): string {
  if (!path) return "";
  if (path.startsWith("http")) return path;
  return `${ASSET_ORIGIN}${path}`;
}

type Options = {
  method?: string;
  body?: unknown;
  auth?: boolean;
  formData?: FormData;
  signal?: AbortSignal;
};

let refreshPromise: Promise<boolean> | null = null;

async function refreshTokens(): Promise<boolean> {
  const refresh = tokenStore.refresh;
  if (!refresh) return false;
  if (!refreshPromise) {
    refreshPromise = (async () => {
      try {
        const response = await fetch(`${API_BASE}/auth/refresh`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refresh_token: refresh }),
        });
        if (!response.ok) return false;
        const data = (await response.json()) as {
          access_token: string;
          refresh_token: string;
        };
        tokenStore.set(data.access_token, data.refresh_token);
        return true;
      } catch {
        return false;
      } finally {
        refreshPromise = null;
      }
    })();
  }
  return refreshPromise;
}

async function parseError(response: Response): Promise<never> {
  let payload: unknown;
  let detail = `Request failed (${response.status})`;
  try {
    payload = await response.json();
    const candidate = payload as { detail?: unknown; error?: unknown };
    if (typeof candidate.detail === "string") detail = candidate.detail;
    else if (typeof candidate.error === "string") detail = candidate.error;
  } catch {
    /* non-JSON error body */
  }
  throw new ApiError(response.status, detail, payload);
}

async function request<T>(path: string, options: Options = {}, retried = false): Promise<T> {
  const { method = "GET", body, auth = true, formData, signal } = options;
  const headers: Record<string, string> = { Accept: "application/json" };

  if (!formData && body !== undefined) headers["Content-Type"] = "application/json";
  if (auth) {
    const token = tokenStore.access;
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: formData ?? (body !== undefined ? JSON.stringify(body) : undefined),
    signal,
  });

  if (response.status === 401 && auth && !retried) {
    const refreshed = await refreshTokens();
    if (refreshed) return request<T>(path, options, true);
    tokenStore.clear();
    window.dispatchEvent(new Event("civicai:unauthorized"));
    return parseError(response);
  }

  if (!response.ok) return parseError(response);
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

export function queryString(params: Record<string, unknown>): string {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "" || value === false) return;
    if (value === true) search.set(key, "true");
    else search.set(key, String(value));
  });
  const result = search.toString();
  return result ? `?${result}` : "";
}

export const api = {
  get: <T>(path: string, params?: Record<string, unknown>, signal?: AbortSignal) =>
    request<T>(`${path}${params ? queryString(params) : ""}`, { signal }),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body }),
  put: <T>(path: string, body?: unknown) => request<T>(path, { method: "PUT", body }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PATCH", body }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
  upload: <T>(path: string, formData: FormData) =>
    request<T>(path, { method: "POST", formData }),
};
