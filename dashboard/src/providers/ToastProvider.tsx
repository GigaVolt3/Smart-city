import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { CheckCircle2, Info, TriangleAlert, X } from "lucide-react";
import { cn } from "../lib/utils";

type ToastKind = "success" | "error" | "info";

type Toast = { id: number; message: string; kind: ToastKind };

type ToastContextValue = {
  notify: (message: string, kind?: ToastKind) => void;
};

const ToastContext = createContext<ToastContextValue | null>(null);

let nextId = 1;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const dismiss = useCallback((id: number) => {
    setToasts((current) => current.filter((toast) => toast.id !== id));
  }, []);

  const notify = useCallback(
    (message: string, kind: ToastKind = "success") => {
      const id = nextId++;
      setToasts((current) => [...current.slice(-3), { id, message, kind }]);
      window.setTimeout(() => dismiss(id), 4600);
    },
    [dismiss],
  );

  const value = useMemo(() => ({ notify }), [notify]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toast-stack" aria-live="polite">
        {toasts.map((toast) => {
          const Icon =
            toast.kind === "success"
              ? CheckCircle2
              : toast.kind === "error"
                ? TriangleAlert
                : Info;
          return (
            <div key={toast.id} className={cn("toast", `toast--${toast.kind}`)}>
              <Icon size={18} />
              <span>{toast.message}</span>
              <button
                type="button"
                onClick={() => dismiss(toast.id)}
                aria-label="Dismiss notification"
              >
                <X size={15} />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const context = useContext(ToastContext);
  if (!context) throw new Error("useToast must be used inside ToastProvider");
  return context;
}
