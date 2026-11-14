import { useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  Building2,
  CheckCircle2,
  ClipboardCopy,
  Clock3,
  Download,
  FileText,
  ImagePlus,
  Layers,
  MapPin,
  MessageSquare,
  ScanSearch,
  ShieldCheck,
  Sparkles,
  Trash2,
  TriangleAlert,
  UserRound,
  WandSparkles,
} from "lucide-react";
import {
  Avatar,
  Button,
  Card,
  ErrorState,
  Field,
  PriorityBadge,
  SectionCard,
  Select,
  Skeleton,
  StatusBadge,
  Textarea,
} from "../components/ui/primitives";
import { ComplaintMap } from "../components/maps/ComplaintMap";
import { useComplaint, useLookups } from "../hooks/queries";
import { useAuth } from "../providers/AuthProvider";
import { useToast } from "../providers/ToastProvider";
import { api, assetUrl } from "../lib/api";
import type {
  ClassificationResult,
  ComplaintStatus,
  DuplicateResult,
  ImageComparison,
  PriorityScore,
  User,
} from "../lib/types";
import {
  cn,
  formatDateTime,
  formatFileSize,
  parseApiDate,
  relativeTime,
  slaState,
  statusMeta,
} from "../lib/utils";

export function ComplaintDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { notify } = useToast();
  const { user } = useAuth();
  const complaintQuery = useComplaint(id);
  const lookups = useLookups();
  const complaint = complaintQuery.data;
  const isStaff = user?.role !== "citizen";
  const canManage =
    user?.role === "admin" ||
    user?.role === "supervisor" ||
    (user?.role === "officer" && complaint?.department_id === user.department_id);

  const [nextStatus, setNextStatus] = useState<ComplaintStatus>("in_progress");
  const [assignee, setAssignee] = useState<string>("");
  const [comments, setComments] = useState("");

  const officers = useQuery({
    queryKey: ["officers", complaint?.department_id],
    queryFn: () =>
      api.get<User[]>("/users/officers", { department_id: complaint?.department_id }),
    enabled: isStaff && Boolean(complaint),
  });

  const statusMutation = useMutation({
    mutationFn: () =>
      api.put(`/complaints/${id}/status`, {
        status: nextStatus,
        comments: comments.trim() || undefined,
        assigned_officer_id: assignee ? Number(assignee) : undefined,
      }),
    onSuccess: () => {
      notify("Complaint updated and the citizen has been notified", "success");
      setComments("");
      complaintQuery.refetch();
      queryClient.invalidateQueries({ queryKey: ["analytics"] });
      queryClient.invalidateQueries({ queryKey: ["complaints"] });
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (error) => notify(error instanceof Error ? error.message : "Update failed", "error"),
  });

  const uploadRef = useRef<HTMLInputElement>(null);
  const upload = useMutation({
    mutationFn: (file: File) => {
      const form = new FormData();
      form.append("file", file);
      return api.upload(`/complaints/${id}/attachments`, form);
    },
    onSuccess: () => {
      notify("Evidence uploaded", "success");
      complaintQuery.refetch();
    },
    onError: (error) => notify(error instanceof Error ? error.message : "Upload failed", "error"),
  });

  const removeAttachment = useMutation({
    mutationFn: (attachmentId: number) =>
      api.delete(`/complaints/${id}/attachments/${attachmentId}`),
    onSuccess: () => {
      notify("Attachment removed", "info");
      complaintQuery.refetch();
    },
    onError: (error) => notify(error instanceof Error ? error.message : "Could not remove", "error"),
  });

  const [ai, setAi] = useState<{
    classification?: ClassificationResult;
    duplicates?: DuplicateResult;
    priority?: PriorityScore;
  }>({});
  const [aiLoading, setAiLoading] = useState(false);
  const [verification, setVerification] = useState<ImageComparison | null>(null);
  const verifyRef = useRef<HTMLInputElement>(null);

  const classify = async () => {
    if (!complaint) return;
    setAiLoading(true);
    try {
      const results = await Promise.allSettled([
        api.post<ClassificationResult>("/ai/classify", {
          title: complaint.title,
          description: complaint.description,
          department_hint_id: complaint.department_id,
        }),
        api.post<DuplicateResult>("/ai/check-duplicates", {
          title: complaint.title,
          description: complaint.description,
          latitude: complaint.latitude,
          longitude: complaint.longitude,
          category_id: complaint.category_id,
          department_id: complaint.department_id,
          exclude_complaint_id: complaint.id,
          active_only: false,
        }),
        api.post<PriorityScore>("/ai/score-priority", {
          title: complaint.title,
          description: complaint.description,
          category_id: complaint.category_id,
          ward: complaint.ward,
          address: complaint.address,
          landmark: complaint.landmark,
        }),
      ]);
      setAi({
        classification: results[0].status === "fulfilled" ? results[0].value : undefined,
        duplicates: results[1].status === "fulfilled" ? results[1].value : undefined,
        priority: results[2].status === "fulfilled" ? results[2].value : undefined,
      });
      if (results.some((result) => result.status === "rejected")) {
        notify("Some AI analyses could not complete", "error");
      }
    } finally {
      setAiLoading(false);
    }
  };

  const verifyImage = useMutation({
    mutationFn: (file: File) => {
      const form = new FormData();
      form.append("after_image", file);
      return api.upload<ImageComparison>(
        `/ai/verify-complaint-resolution/${id}`,
        form,
      );
    },
    onSuccess: (result) => {
      setVerification(result);
      notify(
        result.is_verified ? "Resolution image verified" : "Image flagged for review",
        result.is_verified ? "success" : "error",
      );
    },
    onError: (error) =>
      notify(error instanceof Error ? error.message : "Verification failed", "error"),
  });

  const actorName = useMemo(() => {
    if (!complaint) return () => "System";
    const map = new Map<number, string>();
    if (complaint.citizen) map.set(complaint.citizen.id, complaint.citizen.full_name);
    if (complaint.assigned_officer)
      map.set(complaint.assigned_officer.id, complaint.assigned_officer.full_name);
    if (user) map.set(user.id, user.full_name);
    return (changedById?: number | null) =>
      changedById ? map.get(changedById) ?? `User #${changedById}` : "CivicAI Engine";
  }, [complaint, user]);

  if (complaintQuery.isLoading) {
    return (
      <div className="page">
        <Skeleton className="skeleton--title" />
        <Skeleton className="skeleton--panel" />
      </div>
    );
  }

  if (complaintQuery.error || !complaint) {
    return (
      <div className="page">
        <ErrorState
          message={complaintQuery.error instanceof Error ? complaintQuery.error.message : undefined}
          onRetry={() => complaintQuery.refetch()}
        />
      </div>
    );
  }

  const department =
    complaint.department ?? lookups.departments.find((item) => item.id === complaint.department_id);
  const category =
    complaint.category ?? lookups.categories.find((item) => item.id === complaint.category_id);
  const sla = slaState(complaint.due_at, complaint.status);
  const due = parseApiDate(complaint.due_at);
  const created = parseApiDate(complaint.created_at);
  const slaProgress = (() => {
    if (!due || !created) return 100;
    const total = due.getTime() - created.getTime();
    if (total <= 0) return 100;
    const elapsed = Date.now() - created.getTime();
    return Math.min(100, Math.max(0, (elapsed / total) * 100));
  })();

  const imageAttachments = complaint.attachments.filter((file) =>
    file.mime_type.startsWith("image/"),
  );
  const history = [...complaint.status_history].sort(
    (a, b) =>
      (parseApiDate(a.created_at)?.getTime() ?? 0) -
      (parseApiDate(b.created_at)?.getTime() ?? 0),
  );

  return (
    <div className="page">
      <div className="detail-topline">
        <button type="button" className="back-link" onClick={() => navigate("/complaints")}>
          <ArrowLeft size={16} /> Complaint queue
        </button>
        <div className="detail-topline__meta">
          <span className="mono">{complaint.complaint_number}</span>
          <button
            type="button"
            className="icon-button"
            aria-label="Copy complaint link"
            onClick={() => {
              navigator.clipboard.writeText(window.location.href);
              notify("Link copied", "info");
            }}
          >
            <ClipboardCopy size={16} />
          </button>
        </div>
      </div>

      <header className="detail-header">
        <div className="detail-header__main">
          <div className="detail-header__badges">
            <StatusBadge status={complaint.status} />
            <PriorityBadge priority={complaint.priority} />
            {complaint.escalation_level > 0 && (
              <span className="badge badge--escalated">
                <TriangleAlert size={12} /> Escalation L{complaint.escalation_level}
              </span>
            )}
          </div>
          <h1>{complaint.title}</h1>
          <p className="detail-header__meta">
            <span>
              <Building2 size={14} /> {department?.name ?? "Unassigned department"}
            </span>
            <span>
              <Layers size={14} /> {category?.name ?? "Uncategorised"}
            </span>
            <span>
              <MapPin size={14} /> {complaint.ward}
            </span>
            <span>
              <Clock3 size={14} /> Filed {relativeTime(complaint.created_at)}
            </span>
          </p>
        </div>
      </header>

      <div className="detail-grid">
        <div className="detail-main">
          <SectionCard title="Complaint details" description="Citizen-submitted report">
            <p className="detail-description">{complaint.description}</p>
            <dl className="fact-grid">
              <div>
                <dt>Address</dt>
                <dd>{complaint.address}</dd>
              </div>
              <div>
                <dt>Landmark</dt>
                <dd>{complaint.landmark || "—"}</dd>
              </div>
              <div>
                <dt>Filed on</dt>
                <dd>{formatDateTime(complaint.created_at)}</dd>
              </div>
              <div>
                <dt>Last update</dt>
                <dd>{formatDateTime(complaint.updated_at)}</dd>
              </div>
            </dl>
          </SectionCard>

          <SectionCard
            title="Resolution timeline"
            description={`${history.length} status event${history.length === 1 ? "" : "s"} recorded`}
          >
            <ol className="timeline">
              {history.map((entry) => {
                const meta = statusMeta[entry.new_status as ComplaintStatus] ?? statusMeta.submitted;
                return (
                  <li key={entry.id} className={cn(entry.new_status === "escalated" && "timeline--alert")}>
                    <span className="timeline__marker" style={{ borderColor: meta.dot }}>
                      <span style={{ background: meta.dot }} />
                    </span>
                    <div className="timeline__body">
                      <div className="timeline__head">
                        <strong>{meta.label}</strong>
                        <span>{formatDateTime(entry.created_at)}</span>
                      </div>
                      {entry.comments && <p>{entry.comments}</p>}
                      <span className="timeline__actor">
                        {actorName(entry.changed_by_id)}
                      </span>
                    </div>
                  </li>
                );
              })}
            </ol>
          </SectionCard>

          <SectionCard
            title="Evidence"
            description="Photos and documents attached to this complaint"
            action={
              <Button
                variant="outline"
                size="sm"
                icon={<ImagePlus size={15} />}
                loading={upload.isPending}
                onClick={() => uploadRef.current?.click()}
              >
                Add file
              </Button>
            }
          >
            <input
              ref={uploadRef}
              type="file"
              hidden
              accept="image/*,application/pdf"
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) upload.mutate(file);
                event.target.value = "";
              }}
            />
            {complaint.attachments.length === 0 ? (
              <div className="evidence-empty">
                <ImagePlus size={22} />
                <p>No evidence attached yet.</p>
                <span>Upload a photo or PDF up to 8 MB.</span>
              </div>
            ) : (
              <div className="evidence-grid">
                {complaint.attachments.map((file) => (
                  <div key={file.id} className="evidence-item">
                    {file.mime_type.startsWith("image/") ? (
                      <a href={assetUrl(file.file_path)} target="_blank" rel="noreferrer">
                        <img src={assetUrl(file.file_path)} alt={file.file_name} loading="lazy" />
                      </a>
                    ) : (
                      <a
                        href={assetUrl(file.file_path)}
                        target="_blank"
                        rel="noreferrer"
                        className="evidence-file"
                      >
                        <FileText size={26} />
                        <span>{file.file_name}</span>
                      </a>
                    )}
                    <div className="evidence-item__meta">
                      <span>{formatFileSize(file.file_size)}</span>
                      <div>
                        <a
                          href={assetUrl(file.file_path)}
                          download={file.file_name}
                          className="icon-button"
                          aria-label="Download evidence"
                        >
                          <Download size={14} />
                        </a>
                        <button
                          type="button"
                          className="icon-button icon-button--danger"
                          aria-label="Delete evidence"
                          onClick={() => {
                            if (window.confirm(`Delete ${file.file_name}?`)) {
                              removeAttachment.mutate(file.id);
                            }
                          }}
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {isStaff && (
              <div className="verify-panel">
                <div>
                  <h3>
                    <ShieldCheck size={16} /> Resolution verification
                  </h3>
                  <p>
                    Compare an officer's completion photo against the original evidence using
                    computer vision.
                  </p>
                </div>
                <Button
                  variant="secondary"
                  size="sm"
                  icon={<ScanSearch size={15} />}
                  loading={verifyImage.isPending}
                  disabled={imageAttachments.length === 0}
                  onClick={() => verifyRef.current?.click()}
                >
                  Verify completion photo
                </Button>
                <input
                  ref={verifyRef}
                  type="file"
                  hidden
                  accept="image/*"
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    if (file) verifyImage.mutate(file);
                    event.target.value = "";
                  }}
                />
                {imageAttachments.length === 0 && (
                  <p className="field__hint">
                    Add an original photo to this complaint before verification.
                  </p>
                )}
                {verification && (
                  <div
                    className={cn(
                      "verification-result",
                      verification.is_verified ? "is-verified" : "is-flagged",
                    )}
                  >
                    <strong>
                      {verification.verification_status.replaceAll("_", " ")} ·{" "}
                      {verification.resolution_score}/100
                    </strong>
                    <p>{verification.explanation}</p>
                    <span>Model confidence {(verification.confidence * 100).toFixed(0)}%</span>
                  </div>
                )}
              </div>
            )}
          </SectionCard>

          {isStaff && (
            <SectionCard
              title="AI analysis"
              description="Run the civic intelligence engine against this complaint"
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  icon={<WandSparkles size={15} />}
                  loading={aiLoading}
                  onClick={classify}
                >
                  Run analysis
                </Button>
              }
            >
              {!ai.classification && !ai.duplicates && !ai.priority ? (
                <div className="ai-placeholder">
                  <Sparkles size={20} />
                  <div>
                    <strong>Classification, duplicate detection and priority scoring</strong>
                    <p>
                      The engine reads the title, description and location to surface a
                      recommendation. Nothing is applied automatically.
                    </p>
                  </div>
                </div>
              ) : (
                <div className="ai-grid">
                  {ai.classification && (
                    <article className="ai-card">
                      <span className="ai-card__label">Classification</span>
                      <strong>{ai.classification.category_name ?? "No match"}</strong>
                      <p>
                        {ai.classification.department_name ?? "—"} ·{" "}
                        {(ai.classification.confidence * 100).toFixed(0)}% confidence
                      </p>
                      {ai.classification.matched_keywords.length > 0 && (
                        <div className="tags">
                          {ai.classification.matched_keywords.slice(0, 6).map((keyword) => (
                            <span key={keyword} className="tag">
                              {keyword}
                            </span>
                          ))}
                        </div>
                      )}
                    </article>
                  )}
                  {ai.priority && (
                    <article className="ai-card">
                      <span className="ai-card__label">Urgency score</span>
                      <strong>
                        {ai.priority.priority_score}/100 · {ai.priority.priority_level}
                      </strong>
                      <p>Recommended SLA: {ai.priority.recommended_sla_hours} hours</p>
                      <ul className="ai-factors">
                        {ai.priority.factors.slice(0, 3).map((factor) => (
                          <li key={factor}>{factor}</li>
                        ))}
                      </ul>
                    </article>
                  )}
                  {ai.duplicates && (
                    <article className="ai-card ai-card--wide">
                      <span className="ai-card__label">Duplicate check</span>
                      <strong>
                        {ai.duplicates.is_duplicate
                          ? `${ai.duplicates.matches.length} potential duplicate${ai.duplicates.matches.length === 1 ? "" : "s"}`
                          : "No duplicates found"}
                      </strong>
                      <p>
                        {ai.duplicates.total_candidates_analyzed} nearby complaints analysed ·{" "}
                        {(ai.duplicates.confidence * 100).toFixed(0)}% confidence
                      </p>
                      {ai.duplicates.matches.length > 0 && (
                        <ul className="duplicate-list">
                          {ai.duplicates.matches.slice(0, 4).map((match) => (
                            <li key={match.complaint_id}>
                              <Link to={`/complaints/${match.complaint_id}`}>
                                {match.complaint_number} · {match.title}
                              </Link>
                              <span>
                                {(match.overall_similarity * 100).toFixed(0)}% match
                                {match.distance_meters
                                  ? ` · ${Math.round(match.distance_meters)} m away`
                                  : ""}
                              </span>
                            </li>
                          ))}
                        </ul>
                      )}
                    </article>
                  )}
                </div>
              )}
            </SectionCard>
          )}
        </div>

        <aside className="detail-side">
          <Card className="side-card">
            <div className={cn("sla-hero", `sla-hero--${sla.state}`)}>
              <span>{sla.state === "breached" ? "SLA breached" : "Resolution deadline"}</span>
              <strong>{sla.label}</strong>
              <span>{formatDateTime(complaint.due_at)}</span>
            </div>
            <div className={cn("sla-progress", `sla-progress--${sla.state}`)}>
              <span style={{ width: `${slaProgress}%` }} />
            </div>
            <dl className="side-facts">
              <div>
                <dt>Status</dt>
                <dd>
                  <StatusBadge status={complaint.status} />
                </dd>
              </div>
              <div>
                <dt>Priority</dt>
                <dd>
                  <PriorityBadge priority={complaint.priority} />
                </dd>
              </div>
              <div>
                <dt>Escalation level</dt>
                <dd>{complaint.escalation_level ? `Level ${complaint.escalation_level}` : "None"}</dd>
              </div>
              <div>
                <dt>Resolved</dt>
                <dd>{complaint.resolved_at ? formatDateTime(complaint.resolved_at) : "—"}</dd>
              </div>
            </dl>
          </Card>

          <Card className="side-card">
            <h2 className="side-card__title">People</h2>
            <div className="person">
              <Avatar name={complaint.citizen?.full_name} size="md" />
              <div>
                <strong>{complaint.citizen?.full_name ?? "Citizen"}</strong>
                <span>Complainant · {complaint.citizen?.ward ?? complaint.ward}</span>
                {complaint.citizen?.phone_number && <span>{complaint.citizen.phone_number}</span>}
              </div>
            </div>
            <div className="person">
              {complaint.assigned_officer ? (
                <Avatar name={complaint.assigned_officer.full_name} size="md" tone="warm" />
              ) : (
                <span className="avatar avatar--md avatar--empty">
                  <UserRound size={16} />
                </span>
              )}
              <div>
                <strong>{complaint.assigned_officer?.full_name ?? "Not assigned"}</strong>
                <span>{complaint.assigned_officer ? "Field officer" : "Awaiting assignment"}</span>
              </div>
            </div>
            {department?.contact_email && (
              <div className="contact-line">
                <Building2 size={14} />
                <a href={`mailto:${department.contact_email}`}>{department.contact_email}</a>
              </div>
            )}
            {department?.contact_phone && (
              <div className="contact-line">
                <MessageSquare size={14} />
                <a href={`tel:${department.contact_phone}`}>{department.contact_phone}</a>
              </div>
            )}
          </Card>

          <Card className="side-card side-card--map">
            <h2 className="side-card__title">Location</h2>
            {complaint.latitude && complaint.longitude ? (
              <>
                <ComplaintMap
                  points={[
                    {
                      id: complaint.id,
                      complaint_number: complaint.complaint_number,
                      title: complaint.title,
                      status: complaint.status,
                      priority: complaint.priority,
                      latitude: complaint.latitude,
                      longitude: complaint.longitude,
                      ward: complaint.ward,
                      category: category?.name ?? "",
                    },
                  ]}
                  height={190}
                />
                <p className="side-card__address">
                  {complaint.address}
                  {complaint.landmark ? ` · ${complaint.landmark}` : ""}
                </p>
                <a
                  className="text-link"
                  href={`https://www.google.com/maps/search/?api=1&query=${complaint.latitude},${complaint.longitude}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Open in Google Maps
                </a>
              </>
            ) : (
              <p className="side-card__address">No coordinates were captured for this complaint.</p>
            )}
          </Card>

          {complaint.escalation_events.length > 0 && (
            <Card className="side-card">
              <h2 className="side-card__title">Escalation record</h2>
              <ol className="escalation-list">
                {complaint.escalation_events.map((event) => (
                  <li key={event.id}>
                    <span>L{event.from_level} → L{event.to_level}</span>
                    <p>{event.reason}</p>
                    <small>{formatDateTime(event.created_at)}</small>
                  </li>
                ))}
              </ol>
            </Card>
          )}

          {isStaff && (
            <Card className="side-card side-card--action">
              <h2 className="side-card__title">
                <CheckCircle2 size={16} /> Update complaint
              </h2>
              {canManage ? (
                <form
                  className="stack"
                  onSubmit={(event) => {
                    event.preventDefault();
                    statusMutation.mutate();
                  }}
                >
                  <Field label="New status" htmlFor="status">
                    <Select
                      id="status"
                      value={nextStatus}
                      onChange={(event) => setNextStatus(event.target.value as ComplaintStatus)}
                    >
                      {Object.entries(statusMeta).map(([value, meta]) => (
                        <option key={value} value={value}>
                          {meta.label}
                        </option>
                      ))}
                    </Select>
                  </Field>
                  <Field label="Assign to" htmlFor="assignee" hint="Optional field officer">
                    <Select
                      id="assignee"
                      value={assignee}
                      onChange={(event) => setAssignee(event.target.value)}
                    >
                      <option value="">Keep current assignee</option>
                      {officers.data?.map((officer) => (
                        <option key={officer.id} value={officer.id}>
                          {officer.full_name} · {officer.role}
                        </option>
                      ))}
                    </Select>
                  </Field>
                  <Field label="Update note" htmlFor="comments" hint="Visible on the citizen timeline">
                    <Textarea
                      id="comments"
                      rows={3}
                      value={comments}
                      onChange={(event) => setComments(event.target.value)}
                      placeholder="Describe the action taken…"
                      maxLength={500}
                    />
                  </Field>
                  <Button type="submit" loading={statusMutation.isPending}>
                    Save update
                  </Button>
                  <p className="field__hint">
                    Citizens and the assigned officer receive an in-app notification.
                  </p>
                </form>
              ) : (
                <div className="notice notice--info">
                  <TriangleAlert size={16} />
                  <span>This complaint belongs to another department. You have read-only access.</span>
                </div>
              )}
            </Card>
          )}
        </aside>
      </div>
    </div>
  );
}
