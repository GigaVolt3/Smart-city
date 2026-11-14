import { useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  ImagePlus,
  Info,
  MapPin,
  Sparkles,
  TriangleAlert,
  X,
} from "lucide-react";
import {
  Button,
  Card,
  ErrorState,
  Field,
  Input,
  PageHeader,
  Select,
  Textarea,
} from "../components/ui/primitives";
import { LocationPickerMap } from "../components/maps/ComplaintMap";
import { useLookups } from "../hooks/queries";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { api } from "../lib/api";
import type { ClassificationResult, Complaint, Priority } from "../lib/types";
import { cn, priorityMeta, WARDS } from "../lib/utils";

const BENGALURU_CENTRE = { latitude: 12.9716, longitude: 77.5946 };

type FormState = {
  department_id: string;
  category_id: string;
  title: string;
  description: string;
  ward: string;
  address: string;
  landmark: string;
  priority: "" | Priority;
  latitude: number | null;
  longitude: number | null;
};

const initialForm: FormState = {
  department_id: "",
  category_id: "",
  title: "",
  description: "",
  ward: WARDS[7],
  address: "",
  landmark: "",
  priority: "",
  latitude: null,
  longitude: null,
};

export function NewComplaintPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { notify } = useToast();
  const { departments, categories, isLoading, error, refetch } = useLookups();

  const [form, setForm] = useState<FormState>({
    ...initialForm,
    ward: user?.ward ?? initialForm.ward,
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [files, setFiles] = useState<File[]>([]);
  const fileInput = useRef<HTMLInputElement>(null);
  const [suggestion, setSuggestion] = useState<ClassificationResult | null>(null);

  const set = <K extends keyof FormState>(key: K, value: FormState[K]) => {
    setForm((current) => ({ ...current, [key]: value }));
    setErrors((current) => {
      if (!current[key]) return current;
      const next = { ...current };
      delete next[key];
      return next;
    });
  };

  const departmentCategories = useMemo(
    () =>
      form.department_id
        ? categories.filter((category) => String(category.department_id) === form.department_id)
        : [],
    [categories, form.department_id],
  );

  const category = categories.find((item) => String(item.id) === form.category_id);
  const department = departments.find((item) => String(item.id) === form.department_id);

  const classify = useMutation({
    mutationFn: () =>
      api.post<ClassificationResult>("/ai/classify", {
        title: form.title,
        description: form.description,
      }),
    onSuccess: (result) => {
      setSuggestion(result);
      if (result.category_id && result.department_id) {
        setForm((current) => ({
          ...current,
          department_id: String(result.department_id),
          category_id: String(result.category_id),
        }));
        notify("Category suggestion applied — review before submitting", "info");
      } else {
        notify("No confident category match — choose one manually", "info");
      }
    },
    onError: (mutationError) =>
      notify(
        mutationError instanceof Error
          ? mutationError.message
          : "The classifier is unavailable right now",
        "error",
      ),
  });

  const createComplaint = useMutation({
    mutationFn: async () => {
      const payload = {
        department_id: Number(form.department_id),
        category_id: Number(form.category_id),
        title: form.title.trim(),
        description: form.description.trim(),
        ward: form.ward,
        address: form.address.trim(),
        landmark: form.landmark.trim() || null,
        latitude: form.latitude,
        longitude: form.longitude,
        priority: form.priority || null,
      };
      const complaint = await api.post<Complaint>("/complaints", payload);
      for (const file of files) {
        const data = new FormData();
        data.append("file", file);
        try {
          await api.upload(`/complaints/${complaint.id}/attachments`, data);
        } catch {
          notify(`Could not attach ${file.name}`, "error");
        }
      }
      return complaint;
    },
    onSuccess: (complaint) => {
      queryClient.invalidateQueries({ queryKey: ["complaints"] });
      queryClient.invalidateQueries({ queryKey: ["analytics"] });
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
      notify(`${complaint.complaint_number} filed successfully`, "success");
      navigate(`/complaints/${complaint.id}`, { replace: true });
    },
    onError: (mutationError) =>
      notify(
        mutationError instanceof Error ? mutationError.message : "Could not submit the complaint",
        "error",
      ),
  });

  if (isLoading) {
    return (
      <div className="page">
        <PageHeader title="Report a civic issue" description="Loading departments and categories…" />
        <Card>
          <div className="inline-loading">Preparing the complaint form…</div>
        </Card>
      </div>
    );
  }

  if (error) {
    return (
      <div className="page">
        <ErrorState
          message={error instanceof Error ? error.message : undefined}
          onRetry={() => refetch()}
        />
      </div>
    );
  }

  const validate = () => {
    const next: Record<string, string> = {};
    if (!form.department_id) next.department_id = "Choose the responsible department";
    if (!form.category_id) next.category_id = "Choose a complaint category";
    if (form.title.trim().length < 5) next.title = "Use at least 5 characters";
    if (form.description.trim().length < 10)
      next.description = "Describe the issue in at least 10 characters";
    if (!form.ward) next.ward = "Select your ward";
    if (form.address.trim().length < 5) next.address = "Add a street address or junction";
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const submit = (event: React.FormEvent) => {
    event.preventDefault();
    if (validate()) createComplaint.mutate();
  };

  const canSuggest = form.title.trim().length >= 5 && form.description.trim().length >= 10;

  return (
    <div className="page">
      <div className="detail-topline">
        <button type="button" className="back-link" onClick={() => navigate(-1)}>
          <ArrowLeft size={16} /> Back
        </button>
        <span className="detail-topline__meta">New grievance</span>
      </div>

      <PageHeader
        eyebrow="Citizen intake"
        title="Report a civic issue"
        description="Give the municipality enough detail to route and resolve the issue. AI can suggest the right department and category from your description."
      />

      <form className="compose-grid" onSubmit={submit} noValidate>
        <div className="compose-main">
          <Card className="compose-card">
            <div className="compose-step">
              <span>1</span>
              <div>
                <h2>Describe the issue</h2>
                <p>Be specific about what is broken and where.</p>
              </div>
            </div>

            <Field label="Complaint title" htmlFor="title" error={errors.title} required>
              <Input
                id="title"
                value={form.title}
                onChange={(event) => set("title", event.target.value)}
                placeholder="e.g. Streetlight not working near 4th cross"
                maxLength={150}
              />
            </Field>

            <Field
              label="What is happening?"
              htmlFor="description"
              error={errors.description}
              hint={`${form.description.trim().length}/1000 characters`}
              required
            >
              <Textarea
                id="description"
                rows={6}
                value={form.description}
                onChange={(event) => set("description", event.target.value.slice(0, 1000))}
                placeholder="Describe the problem, how long it has existed, and any safety risk…"
              />
            </Field>

            <div className="ai-suggest">
              <div>
                <Sparkles size={17} />
                <div>
                  <strong>Not sure which department?</strong>
                  <p>Classify this complaint from the text you have already written.</p>
                </div>
              </div>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                loading={classify.isPending}
                disabled={!canSuggest}
                onClick={() => classify.mutate()}
              >
                Suggest routing
              </Button>
            </div>

            {suggestion && (
              <div className="ai-suggestion">
                <CheckCircle2 size={16} />
                <div>
                  <strong>
                    {suggestion.category_name ?? "No category match"} ·{" "}
                    {suggestion.department_name ?? "Unassigned"}
                  </strong>
                  <p>
                    {Math.round(suggestion.confidence * 100)}% confidence
                    {suggestion.matched_keywords.length
                      ? ` · matched ${suggestion.matched_keywords.slice(0, 4).join(", ")}`
                      : ""}
                  </p>
                </div>
                <button
                  type="button"
                  className="icon-button"
                  aria-label="Dismiss suggestion"
                  onClick={() => setSuggestion(null)}
                >
                  <X size={15} />
                </button>
              </div>
            )}
          </Card>

          <Card className="compose-card">
            <div className="compose-step">
              <span>2</span>
              <div>
                <h2>Route the complaint</h2>
                <p>The department owns the SLA; the category sets its deadline.</p>
              </div>
            </div>

            <div className="form-grid">
              <Field
                label="Department"
                htmlFor="department"
                error={errors.department_id}
                required
              >
                <Select
                  id="department"
                  value={form.department_id}
                  onChange={(event) => {
                    set("department_id", event.target.value);
                    set("category_id", "");
                  }}
                >
                  <option value="">Select department</option>
                  {departments.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.name}
                    </option>
                  ))}
                </Select>
              </Field>

              <Field label="Category" htmlFor="category" error={errors.category_id} required>
                <Select
                  id="category"
                  value={form.category_id}
                  onChange={(event) => set("category_id", event.target.value)}
                  disabled={!form.department_id}
                >
                  <option value="">Select category</option>
                  {departmentCategories.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.name}
                    </option>
                  ))}
                </Select>
              </Field>
            </div>

            {category && (
              <div className="category-hint">
                <Info size={15} />
                <span>
                  {category.name} is handled by {department?.name ?? "the department"} with a{" "}
                  <strong>{category.sla_hours}h</strong> resolution target. Default priority{" "}
                  <strong>{priorityMeta[category.priority_default].label}</strong>.
                </span>
              </div>
            )}

            <Field
              label="Priority"
              htmlFor="priority"
              hint="Leave automatic to let CivicAI score urgency from the text and category."
            >
              <Select
                id="priority"
                value={form.priority}
                onChange={(event) => set("priority", event.target.value as "" | Priority)}
              >
                <option value="">Automatic (AI-scored)</option>
                {Object.entries(priorityMeta)
                  .sort(([, a], [, b]) => b.rank - a.rank)
                  .map(([value, meta]) => (
                    <option key={value} value={value}>
                      {meta.label}
                    </option>
                  ))}
              </Select>
            </Field>
          </Card>

          <Card className="compose-card">
            <div className="compose-step">
              <span>3</span>
              <div>
                <h2>Pin the location</h2>
                <p>Click the map to drop a precise pin, then add the street address.</p>
              </div>
            </div>

            <div className="form-grid">
              <Field label="Ward" htmlFor="ward" error={errors.ward} required>
                <Select
                  id="ward"
                  value={form.ward}
                  onChange={(event) => set("ward", event.target.value)}
                >
                  {WARDS.map((ward) => (
                    <option key={ward} value={ward}>
                      {ward}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label="Landmark" htmlFor="landmark" hint="Optional nearby reference">
                <Input
                  id="landmark"
                  value={form.landmark}
                  onChange={(event) => set("landmark", event.target.value)}
                  placeholder="Opposite the ward office"
                  maxLength={150}
                />
              </Field>
            </div>

            <Field label="Street address" htmlFor="address" error={errors.address} required>
              <Input
                id="address"
                value={form.address}
                onChange={(event) => set("address", event.target.value)}
                placeholder="Building, street, cross, area"
                maxLength={255}
              />
            </Field>

            <LocationPickerMap
              latitude={form.latitude}
              longitude={form.longitude}
              onChange={(latitude, longitude) => {
                set("latitude", Number(latitude.toFixed(6)));
                set("longitude", Number(longitude.toFixed(6)));
              }}
              height={300}
            />

            <div className="coordinate-row">
              <span>
                <MapPin size={14} />
                {form.latitude && form.longitude
                  ? `${form.latitude.toFixed(5)}, ${form.longitude.toFixed(5)}`
                  : `No pin yet · map starts at Bengaluru centre (${BENGALURU_CENTRE.latitude}, ${BENGALURU_CENTRE.longitude})`}
              </span>
              {(form.latitude || form.longitude) && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    set("latitude", null);
                    set("longitude", null);
                  }}
                >
                  Clear pin
                </Button>
              )}
            </div>
          </Card>

          <Card className="compose-card">
            <div className="compose-step">
              <span>4</span>
              <div>
                <h2>Attach evidence</h2>
                <p>Photos help officers verify the issue. Up to 6 files, 8 MB each.</p>
              </div>
            </div>

            <input
              ref={fileInput}
              type="file"
              hidden
              multiple
              accept="image/*,application/pdf"
              onChange={(event) => {
                const selected = Array.from(event.target.files ?? []);
                setFiles((current) => [...current, ...selected].slice(0, 6));
                event.target.value = "";
              }}
            />

            {files.length === 0 ? (
              <button
                type="button"
                className="upload-dropzone"
                onClick={() => fileInput.current?.click()}
              >
                <ImagePlus size={22} />
                <strong>Add photos or documents</strong>
                <span>PNG, JPG or PDF · 8 MB maximum per file</span>
              </button>
            ) : (
              <ul className="upload-list">
                {files.map((file, index) => (
                  <li key={`${file.name}-${index}`}>
                    <ImagePlus size={16} />
                    <span>{file.name}</span>
                    <small>{Math.round(file.size / 1024)} KB</small>
                    <button
                      type="button"
                      className="icon-button icon-button--danger"
                      aria-label={`Remove ${file.name}`}
                      onClick={() => setFiles((current) => current.filter((_, i) => i !== index))}
                    >
                      <X size={14} />
                    </button>
                  </li>
                ))}
              </ul>
            )}

            {files.length > 0 && files.length < 6 && (
              <Button
                type="button"
                variant="outline"
                size="sm"
                icon={<ImagePlus size={15} />}
                onClick={() => fileInput.current?.click()}
              >
                Add another file
              </Button>
            )}
          </Card>
        </div>

        <aside className="compose-side">
          <Card className="side-card compose-summary">
            <h2 className="side-card__title">Submission summary</h2>
            <dl className="side-facts">
              <div>
                <dt>Department</dt>
                <dd>{department?.name ?? "Not selected"}</dd>
              </div>
              <div>
                <dt>Category</dt>
                <dd>{category?.name ?? "Not selected"}</dd>
              </div>
              <div>
                <dt>SLA target</dt>
                <dd>{category ? `${category.sla_hours} hours` : "Set after routing"}</dd>
              </div>
              <div>
                <dt>Priority</dt>
                <dd>
                  {form.priority ? (
                    <span className="inline-priority">
                      <span
                        className="dot"
                        style={{ background: priorityMeta[form.priority].dot }}
                      />
                      {priorityMeta[form.priority].label}
                    </span>
                  ) : (
                    "AI-scored on submit"
                  )}
                </dd>
              </div>
              <div>
                <dt>Location</dt>
                <dd>
                  {form.latitude && form.longitude
                    ? `${form.latitude.toFixed(4)}, ${form.longitude.toFixed(4)}`
                    : "No map pin"}
                </dd>
              </div>
              <div>
                <dt>Evidence</dt>
                <dd>{files.length ? `${files.length} file(s)` : "None"}</dd>
              </div>
            </dl>

            <Button
              type="submit"
              size="lg"
              className={cn("compose-submit")}
              loading={createComplaint.isPending}
            >
              Submit complaint
              <ArrowRight size={17} />
            </Button>
            <p className="field__hint">
              You will receive a complaint reference and in-app updates as the status changes.
            </p>
          </Card>

          <Card className="side-card">
            <h2 className="side-card__title">
              <TriangleAlert size={16} /> Before you submit
            </h2>
            <ul className="compose-tips">
              <li>Search the map first to avoid filing a duplicate.</li>
              <li>Do not include personal information about other people.</li>
              <li>For emergencies, call the control room instead of filing online.</li>
            </ul>
          </Card>
        </aside>
      </form>
    </div>
  );
}
