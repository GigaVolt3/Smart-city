import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { api, tokenStore } from "../lib/api";
import type { TokenResponse, User } from "../lib/types";

type RegisterPayload = {
  email: string;
  password: string;
  full_name: string;
  phone_number?: string;
  ward?: string;
};

type AuthContextValue = {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<User>;
  register: (payload: RegisterPayload) => Promise<User>;
  logout: () => void;
  refreshUser: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    const bootstrap = async () => {
      if (!tokenStore.access) {
        setLoading(false);
        return;
      }
      try {
        const me = await api.get<User>("/auth/me");
        if (!cancelled) setUser(me);
      } catch {
        tokenStore.clear();
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    bootstrap();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const handleUnauthorized = () => setUser(null);
    window.addEventListener("civicai:unauthorized", handleUnauthorized);
    return () => window.removeEventListener("civicai:unauthorized", handleUnauthorized);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const data = await api.post<TokenResponse>("/auth/login", { email, password });
    tokenStore.set(data.access_token, data.refresh_token);
    setUser(data.user);
    return data.user;
  }, []);

  const register = useCallback(async (payload: RegisterPayload) => {
    const data = await api.post<TokenResponse>("/auth/register", payload);
    tokenStore.set(data.access_token, data.refresh_token);
    setUser(data.user);
    return data.user;
  }, []);

  const logout = useCallback(() => {
    tokenStore.clear();
    setUser(null);
  }, []);

  const refreshUser = useCallback(async () => {
    const me = await api.get<User>("/auth/me");
    setUser(me);
  }, []);

  const value = useMemo(
    () => ({ user, loading, login, register, logout, refreshUser }),
    [user, loading, login, register, logout, refreshUser],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used inside AuthProvider");
  return context;
}
