import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ArrowRight } from "lucide-react";
import { AuthLayout } from "../components/auth/AuthLayout";
import { Button, Field, Input, Select } from "../components/ui/primitives";
import { useAuth } from "../providers/AuthProvider";
import { ApiError } from "../lib/api";
import { WARDS } from "../lib/utils";

const schema = z
  .object({
    full_name: z.string().min(2, "Enter your full name").max(100),
    email: z.string().min(1, "Email is required").email("Enter a valid email address"),
    phone_number: z
      .string()
      .min(8, "Enter a valid phone number")
      .max(20, "Phone number is too long"),
    ward: z.string().min(1, "Select your ward"),
    password: z.string().min(8, "Use at least 8 characters"),
    confirm_password: z.string(),
  })
  .refine((values) => values.password === values.confirm_password, {
    path: ["confirm_password"],
    message: "Passwords do not match",
  });

type FormValues = z.infer<typeof schema>;

export function RegisterPage() {
  const { user, register: registerUser } = useAuth();
  const navigate = useNavigate();
  const [formError, setFormError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { ward: WARDS[5] },
  });

  if (user) return <Navigate to="/" replace />;

  const onSubmit = async (values: FormValues) => {
    setFormError(null);
    try {
      await registerUser({
        email: values.email,
        password: values.password,
        full_name: values.full_name,
        phone_number: values.phone_number,
        ward: values.ward,
      });
      navigate("/", { replace: true });
    } catch (error) {
      setFormError(
        error instanceof ApiError
          ? error.detail
          : "Unable to create your account. Please try again.",
      );
    }
  };

  return (
    <AuthLayout
      footer={
        <p className="auth__switch">
          Already have an account? <Link to="/login">Sign in</Link>
        </p>
      }
    >
      <header className="auth__header">
        <p className="auth__kicker">Citizen registration</p>
        <h2>Report issues in your ward</h2>
        <p>Create an account to file civic complaints and follow every update.</p>
      </header>

      {formError && (
        <div className="alert alert--error" role="alert">
          {formError}
        </div>
      )}

      <form className="auth__form" onSubmit={handleSubmit(onSubmit)} noValidate>
        <Field label="Full name" htmlFor="full_name" error={errors.full_name?.message} required>
          <Input id="full_name" placeholder="Your name" {...register("full_name")} />
        </Field>

        <div className="form-grid">
          <Field label="Email address" htmlFor="email" error={errors.email?.message} required>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              {...register("email")}
            />
          </Field>
          <Field
            label="Phone number"
            htmlFor="phone_number"
            error={errors.phone_number?.message}
            required
          >
            <Input id="phone_number" placeholder="+91 98765 43210" {...register("phone_number")} />
          </Field>
        </div>

        <Field label="Ward" htmlFor="ward" error={errors.ward?.message} required>
          <Select id="ward" {...register("ward")}>
            {WARDS.map((ward) => (
              <option key={ward} value={ward}>
                {ward}
              </option>
            ))}
          </Select>
        </Field>

        <div className="form-grid">
          <Field
            label="Password"
            htmlFor="password"
            hint="Minimum 8 characters"
            error={errors.password?.message}
            required
          >
            <Input
              id="password"
              type="password"
              autoComplete="new-password"
              {...register("password")}
            />
          </Field>
          <Field
            label="Confirm password"
            htmlFor="confirm_password"
            error={errors.confirm_password?.message}
            required
          >
            <Input
              id="confirm_password"
              type="password"
              autoComplete="new-password"
              {...register("confirm_password")}
            />
          </Field>
        </div>

        <Button type="submit" size="lg" loading={isSubmitting} className="auth__submit">
          Create account
          <ArrowRight size={17} />
        </Button>
      </form>
    </AuthLayout>
  );
}
