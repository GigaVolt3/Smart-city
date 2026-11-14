import { useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ArrowRight, Eye, EyeOff, ShieldCheck } from "lucide-react";
import { AuthLayout } from "../components/auth/AuthLayout";
import { Button, Field, Input } from "../components/ui/primitives";
import { useAuth } from "../providers/AuthProvider";
import { ApiError } from "../lib/api";

const schema = z.object({
  email: z.string().min(1, "Email is required").email("Enter a valid email address"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

type FormValues = z.infer<typeof schema>;

const demoAccounts = [
  { role: "Citizen", email: "citizen@demo.civicai", tone: "citizen" },
  { role: "Officer", email: "officer@demo.civicai", tone: "officer" },
  { role: "Supervisor", email: "supervisor@demo.civicai", tone: "supervisor" },
  { role: "Admin", email: "admin@demo.civicai", tone: "admin" },
];

export function LoginPage() {
  const { user, login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [showPassword, setShowPassword] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { email: "", password: "" },
  });

  if (user) return <Navigate to="/" replace />;

  const onSubmit = async (values: FormValues) => {
    setFormError(null);
    try {
      await login(values.email, values.password);
      const from = (location.state as { from?: string } | null)?.from;
      navigate(from && from !== "/login" ? from : "/", { replace: true });
    } catch (error) {
      setFormError(
        error instanceof ApiError
          ? error.detail
          : "Unable to sign in right now. Check the API connection and try again.",
      );
    }
  };

  return (
    <AuthLayout
      footer={
        <p className="auth__switch">
          New to CivicAI? <Link to="/register">Create a citizen account</Link>
        </p>
      }
    >
      <header className="auth__header">
        <p className="auth__kicker">Welcome back</p>
        <h2>Sign in to your workspace</h2>
        <p>Use your municipal account or explore a role-based demo profile.</p>
      </header>

      {formError && (
        <div className="alert alert--error" role="alert">
          {formError}
        </div>
      )}

      <form className="auth__form" onSubmit={handleSubmit(onSubmit)} noValidate>
        <Field label="Email address" htmlFor="email" error={errors.email?.message} required>
          <Input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="you@municipality.gov.in"
            {...register("email")}
          />
        </Field>

        <Field label="Password" htmlFor="password" error={errors.password?.message} required>
          <div className="input-with-action">
            <Input
              id="password"
              type={showPassword ? "text" : "password"}
              autoComplete="current-password"
              placeholder="Enter your password"
              {...register("password")}
            />
            <button
              type="button"
              className="input-with-action__button"
              onClick={() => setShowPassword((value) => !value)}
              aria-label={showPassword ? "Hide password" : "Show password"}
            >
              {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
            </button>
          </div>
        </Field>

        <Button type="submit" size="lg" loading={isSubmitting} className="auth__submit">
          Sign in
          <ArrowRight size={17} />
        </Button>
      </form>

      <div className="demo-box">
        <div className="demo-box__title">
          <ShieldCheck size={15} />
          <span>Demo environment</span>
        </div>
        <p>Choose a seeded profile — every account uses the password DemoPass1!</p>
        <div className="demo-box__grid">
          {demoAccounts.map((account) => (
            <button
              key={account.email}
              type="button"
              className={`demo-chip demo-chip--${account.tone}`}
              onClick={() => {
                setValue("email", account.email, { shouldValidate: true });
                setValue("password", "DemoPass1!", { shouldValidate: true });
                setFormError(null);
              }}
            >
              {account.role}
            </button>
          ))}
        </div>
      </div>
    </AuthLayout>
  );
}
