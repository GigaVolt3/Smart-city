"""Coverage for the features added on top of the original complaint workflow.

Covers notifications, analytics, escalations, audit trail, profile management,
assignable officers, department/category edits, pagination, SLA filters and
evidence attachments.
"""

from datetime import datetime, timedelta, timezone

import pytest

from backend.models.complaint import Complaint
from backend.models.enums import ComplaintPriority, ComplaintStatus
from backend.models.notification import Notification
from backend.tests.conftest import auth_header_for_user


COMPLAINT_PAYLOAD = {
    "title": "Overflowing storm drain",
    "description": "Drain blocked for two days, water pooling on the footpath.",
    "ward": "Ward 12",
    "address": "12th Main Road",
    "landmark": "Near ward office",
}


def _create_complaint(client, seed_data, headers=None, **overrides):
    payload = {
        "department_id": seed_data["dept"].id,
        "category_id": seed_data["category"].id,
        **COMPLAINT_PAYLOAD,
        **overrides,
    }
    response = client.post(
        "/api/v1/complaints",
        json=payload,
        headers=headers or auth_header_for_user(seed_data["citizen"]),
    )
    assert response.status_code == 201, response.text
    return response.json()


def _make_notification(db_session, user, *, title="Case update", read=False, kind="status"):
    notification = Notification(
        user_id=user.id,
        notification_type=kind,
        title=title,
        message="Your complaint moved forward.",
        is_read=read,
    )
    db_session.add(notification)
    db_session.commit()
    db_session.refresh(notification)
    return notification


# ── Notifications ────────────────────────────────────────────────────────────


def test_notifications_list_and_unread_count(client, seed_data, db_session):
    citizen = seed_data["citizen"]
    _make_notification(db_session, citizen, title="First")
    _make_notification(db_session, citizen, title="Second")
    _make_notification(db_session, seed_data["officer"], title="Officer only")

    headers = auth_header_for_user(citizen)
    listed = client.get("/api/v1/notifications", headers=headers)
    assert listed.status_code == 200
    body = listed.json()
    assert body["total"] == 2
    assert body["unread_count"] == 2
    assert {item["title"] for item in body["items"]} == {"First", "Second"}

    unread = client.get(
        "/api/v1/notifications?unread_only=true", headers=headers
    ).json()
    assert unread["total"] == 2

    count = client.get("/api/v1/notifications/unread-count", headers=headers)
    assert count.status_code == 200
    assert count.json()["unread_count"] == 2


def test_notifications_mark_read_read_all_and_delete(client, seed_data, db_session):
    citizen = seed_data["citizen"]
    first = _make_notification(db_session, citizen, title="First")
    second = _make_notification(db_session, citizen, title="Second")
    headers = auth_header_for_user(citizen)

    single = client.put(f"/api/v1/notifications/{first.id}/read", headers=headers)
    assert single.status_code == 200
    assert single.json()["is_read"] is True

    remaining = client.get("/api/v1/notifications/unread-count", headers=headers)
    assert remaining.json()["unread_count"] == 1

    all_read = client.post("/api/v1/notifications/read-all", headers=headers)
    assert all_read.status_code == 200
    assert all_read.json()["unread_count"] == 0

    deleted = client.delete(f"/api/v1/notifications/{second.id}", headers=headers)
    assert deleted.status_code == 204
    assert client.get("/api/v1/notifications", headers=headers).json()["total"] == 1


def test_notification_of_another_user_is_not_visible(client, seed_data, db_session):
    other = _make_notification(db_session, seed_data["other_citizen"], title="Private")
    headers = auth_header_for_user(seed_data["citizen"])

    assert client.put(f"/api/v1/notifications/{other.id}/read", headers=headers).status_code == 404
    assert client.delete(f"/api/v1/notifications/{other.id}", headers=headers).status_code == 404


# ── Analytics ────────────────────────────────────────────────────────────────


def test_analytics_overview_shape_and_role_scoping(client, seed_data):
    admin_headers = auth_header_for_user(seed_data["admin"])
    citizen_headers = auth_header_for_user(seed_data["citizen"])

    _create_complaint(client, seed_data)
    _create_complaint(client, seed_data, headers=auth_header_for_user(seed_data["other_citizen"]))

    admin = client.get("/api/v1/analytics/overview?days=30", headers=admin_headers)
    assert admin.status_code == 200
    admin_body = admin.json()
    assert admin_body["role"] == "admin"
    assert admin_body["days"] == 30
    assert admin_body["kpis"]["total"] == 2
    for key in (
        "status_breakdown",
        "priority_breakdown",
        "trend",
        "departments",
        "categories",
        "wards",
        "sla",
        "recent_activity",
        "map_points",
        "my",
    ):
        assert key in admin_body

    citizen = client.get("/api/v1/analytics/overview?days=30", headers=citizen_headers)
    assert citizen.status_code == 200
    citizen_body = citizen.json()
    assert citizen_body["role"] == "citizen"
    assert citizen_body["kpis"]["total"] == 1


def test_analytics_rejects_invalid_window(client, seed_data):
    headers = auth_header_for_user(seed_data["admin"])
    assert client.get("/api/v1/analytics/overview?days=0", headers=headers).status_code == 422
    assert client.get("/api/v1/analytics/overview?days=400", headers=headers).status_code == 422


# ── Escalations ──────────────────────────────────────────────────────────────


def test_escalation_summary_events_and_run(client, seed_data):
    _create_complaint(client, seed_data)
    admin_headers = auth_header_for_user(seed_data["admin"])

    summary = client.get("/api/v1/escalations/summary", headers=admin_headers)
    assert summary.status_code == 200
    body = summary.json()
    assert body["open_escalated"] == 0
    assert body["total_events"] == 0
    assert "by_level" in body
    assert "by_department" in body

    events = client.get("/api/v1/escalations/events", headers=admin_headers)
    assert events.status_code == 200
    assert isinstance(events.json(), list)

    rules = client.get("/api/v1/escalations/rules", headers=admin_headers)
    assert rules.status_code == 200
    assert isinstance(rules.json(), list)

    run = client.post("/api/v1/escalations/run", headers=admin_headers)
    assert run.status_code == 200
    assert set(run.json()) >= {"escalated", "events"}


def test_escalation_engine_reason_text_is_human_readable(client, seed_data, db_session):
    from backend.models.escalation import EscalationRule
    from backend.services.escalation_engine import process_escalations

    if not db_session.query(EscalationRule).count():
        db_session.add(
            EscalationRule(escalation_level=1, trigger_hours=0, target_role="supervisor")
        )
        db_session.commit()

    created = _create_complaint(client, seed_data)
    complaint = db_session.query(Complaint).filter(Complaint.id == created["id"]).first()
    complaint.due_at = datetime.now(timezone.utc) - timedelta(hours=30)
    db_session.commit()

    events = process_escalations(db_session)
    db_session.commit()

    ours = [event for event in events if event.complaint_id == created["id"]]
    assert ours, "expected the overdue complaint to escalate"
    first = ours[0]
    assert "SLA deadline exceeded by" in first.reason
    assert "0.0h" not in first.reason
    assert f"level {first.to_level}" in first.reason


def test_escalation_run_is_restricted_to_supervisors(client, seed_data):
    citizen_headers = auth_header_for_user(seed_data["citizen"])
    assert client.post("/api/v1/escalations/run", headers=citizen_headers).status_code == 403

    supervisor_headers = auth_header_for_user(seed_data["supervisor"])
    assert client.post("/api/v1/escalations/run", headers=supervisor_headers).status_code == 200


# ── Audit trail ──────────────────────────────────────────────────────────────


def test_audit_trail_records_actions_for_admins_only(client, seed_data):
    _create_complaint(client, seed_data)

    admin_headers = auth_header_for_user(seed_data["admin"])
    admin_events = client.get("/api/v1/audit", headers=admin_headers)
    assert admin_events.status_code == 200
    actions = [event["action"] for event in admin_events.json()]
    assert "complaint.created" in actions
    assert all("user_name" in event for event in admin_events.json())

    filtered = client.get("/api/v1/audit?action=complaint.", headers=admin_headers)
    assert filtered.status_code == 200
    assert all(event["action"].startswith("complaint.") for event in filtered.json())

    officer_headers = auth_header_for_user(seed_data["officer"])
    assert client.get("/api/v1/audit", headers=officer_headers).status_code == 403


# ── Profile & password ───────────────────────────────────────────────────────


def test_profile_update_and_password_change(client, seed_data):
    headers = auth_header_for_user(seed_data["citizen"])

    updated = client.put(
        "/api/v1/auth/me",
        json={"full_name": "Citizen Renamed", "phone_number": "9998887770"},
        headers=headers,
    )
    assert updated.status_code == 200
    assert updated.json()["full_name"] == "Citizen Renamed"
    assert updated.json()["phone_number"] == "9998887770"

    me = client.get("/api/v1/auth/me", headers=headers)
    assert me.json()["full_name"] == "Citizen Renamed"

    wrong = client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "not-the-password", "new_password": "BrandNew1!"},
        headers=headers,
    )
    assert wrong.status_code == 400

    same = client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "TestSecret123!", "new_password": "TestSecret123!"},
        headers=headers,
    )
    assert same.status_code == 400

    changed = client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "TestSecret123!", "new_password": "BrandNew1!"},
        headers=headers,
    )
    assert changed.status_code == 200

    relogin = client.post(
        "/api/v1/auth/login",
        json={"email": "citizen@test.civicai", "password": "BrandNew1!"},
    )
    assert relogin.status_code == 200
    assert relogin.json()["access_token"]


# ── Officers, departments, categories ────────────────────────────────────────


def test_assignable_officers_endpoint(client, seed_data):
    admin_headers = auth_header_for_user(seed_data["admin"])
    response = client.get("/api/v1/users/officers", headers=admin_headers)
    assert response.status_code == 200
    emails = [user["email"] for user in response.json()]
    assert "officer@test.civicai" in emails
    assert "supervisor@test.civicai" in emails
    assert "citizen@test.civicai" not in emails

    citizen_headers = auth_header_for_user(seed_data["citizen"])
    assert client.get("/api/v1/users/officers", headers=citizen_headers).status_code == 403


def test_department_and_category_updates(client, seed_data):
    admin_headers = auth_header_for_user(seed_data["admin"])

    dept = client.patch(
        f"/api/v1/departments/{seed_data['dept'].id}",
        json={"contact_email": "new-roads@test.civicai", "description": "Updated scope"},
        headers=admin_headers,
    )
    assert dept.status_code == 200
    assert dept.json()["contact_email"] == "new-roads@test.civicai"

    cat = client.patch(
        f"/api/v1/categories/{seed_data['category'].id}",
        json={"sla_hours": 72, "priority_default": "high"},
        headers=admin_headers,
    )
    assert cat.status_code == 200
    assert cat.json()["sla_hours"] == 72
    assert cat.json()["priority_default"] == "high"

    officer_headers = auth_header_for_user(seed_data["officer"])
    denied = client.patch(
        f"/api/v1/departments/{seed_data['dept'].id}",
        json={"contact_email": "nope@test.civicai"},
        headers=officer_headers,
    )
    assert denied.status_code == 403


# ── Pagination, SLA and assignment filters ───────────────────────────────────


def test_paged_complaints_with_total(client, seed_data):
    for index in range(3):
        _create_complaint(client, seed_data, title=f"Drain block {index}")

    headers = auth_header_for_user(seed_data["citizen"])
    page = client.get("/api/v1/complaints/paged?skip=0&limit=2", headers=headers)
    assert page.status_code == 200
    body = page.json()
    assert body["total"] == 3
    assert len(body["items"]) == 2
    assert body["skip"] == 0
    assert body["limit"] == 2

    second = client.get("/api/v1/complaints/paged?skip=2&limit=2", headers=headers).json()
    assert len(second["items"]) == 1


def test_overdue_and_assigned_to_me_filters(client, seed_data, db_session):
    created = _create_complaint(client, seed_data)
    complaint = db_session.query(Complaint).filter(Complaint.id == created["id"]).first()
    complaint.due_at = datetime.now(timezone.utc) - timedelta(hours=6)
    complaint.assigned_officer_id = seed_data["officer"].id
    complaint.status = ComplaintStatus.IN_PROGRESS.value
    complaint.priority = ComplaintPriority.HIGH.value
    db_session.commit()

    admin_headers = auth_header_for_user(seed_data["admin"])
    overdue = client.get("/api/v1/complaints?overdue=true", headers=admin_headers).json()
    assert [item["id"] for item in overdue] == [created["id"]]

    officer_headers = auth_header_for_user(seed_data["officer"])
    mine = client.get(
        "/api/v1/complaints?assigned_to_me=true", headers=officer_headers
    ).json()
    assert [item["id"] for item in mine] == [created["id"]]

    other_headers = auth_header_for_user(seed_data["other_citizen"])
    assert client.get(
        "/api/v1/complaints?assigned_to_me=true", headers=other_headers
    ).json() == []


def test_status_update_creates_timeline_and_notification(client, seed_data):
    created = _create_complaint(client, seed_data)
    officer_headers = auth_header_for_user(seed_data["officer"])

    updated = client.put(
        f"/api/v1/complaints/{created['id']}/status",
        json={
            "status": "in_progress",
            "comments": "Road crew dispatched",
            "assigned_officer_id": seed_data["officer"].id,
        },
        headers=officer_headers,
    )
    assert updated.status_code == 200
    assert updated.json()["status"] == "in_progress"

    timeline = client.get(
        f"/api/v1/complaints/{created['id']}/timeline", headers=officer_headers
    )
    assert timeline.status_code == 200
    assert len(timeline.json()) >= 2

    citizen_headers = auth_header_for_user(seed_data["citizen"])
    inbox = client.get("/api/v1/notifications", headers=citizen_headers).json()
    assert inbox["total"] >= 1
    assert any(item["notification_type"] == "status_change" for item in inbox["items"])

    officer_inbox = client.get("/api/v1/notifications", headers=officer_headers).json()
    assert any(
        item["notification_type"] == "assignment" for item in officer_inbox["items"]
    )


# ── Attachments ──────────────────────────────────────────────────────────────


@pytest.fixture
def upload_dir(tmp_path, monkeypatch):
    from backend.services import uploads as uploads_module

    monkeypatch.setattr(uploads_module.settings, "UPLOAD_DIR", str(tmp_path))
    return tmp_path


def test_attachment_upload_list_and_delete(client, seed_data, upload_dir):
    created = _create_complaint(client, seed_data)
    headers = auth_header_for_user(seed_data["citizen"])

    upload = client.post(
        f"/api/v1/complaints/{created['id']}/attachments",
        files={"file": ("evidence.png", b"\x89PNG\r\n\x1a\nfake-bytes", "image/png")},
        headers=headers,
    )
    assert upload.status_code == 201, upload.text
    attachment = upload.json()
    assert attachment["file_name"] == "evidence.png"
    assert attachment["mime_type"] == "image/png"

    listed = client.get(
        f"/api/v1/complaints/{created['id']}/attachments", headers=headers
    )
    assert listed.status_code == 200
    assert len(listed.json()) == 1

    deleted = client.delete(
        f"/api/v1/complaints/{created['id']}/attachments/{attachment['id']}",
        headers=headers,
    )
    assert deleted.status_code == 204
    assert client.get(
        f"/api/v1/complaints/{created['id']}/attachments", headers=headers
    ).json() == []


def test_attachment_rejects_unsupported_type(client, seed_data, upload_dir):
    created = _create_complaint(client, seed_data)
    headers = auth_header_for_user(seed_data["citizen"])

    response = client.post(
        f"/api/v1/complaints/{created['id']}/attachments",
        files={"file": ("payload.exe", b"binary", "application/octet-stream")},
        headers=headers,
    )
    assert response.status_code == 415


def test_attachment_rejects_empty_file(client, seed_data, upload_dir):
    created = _create_complaint(client, seed_data)
    headers = auth_header_for_user(seed_data["citizen"])

    response = client.post(
        f"/api/v1/complaints/{created['id']}/attachments",
        files={"file": ("empty.png", b"", "image/png")},
        headers=headers,
    )
    assert response.status_code == 400
