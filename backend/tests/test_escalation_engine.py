from datetime import datetime, timedelta, timezone
import pytest
from sqlalchemy.exc import IntegrityError

from backend.models.complaint import Complaint
from backend.models.escalation import EscalationRule, EscalationEvent
from backend.models.notification import Notification
from backend.models.status_history import StatusHistory
from backend.models.enums import ComplaintStatus, ComplaintPriority, UserRole
from backend.services.deadline_service import (
    calculate_deadline,
    is_overdue,
    calculate_overdue_hours,
    extend_deadline,
)
from backend.services.escalation_service import (
    escalate_complaint,
    check_and_escalate_overdue_complaints,
    get_complaint_escalation_history,
)
from backend.tests.conftest import auth_header_for_user


# ---------------------------------------------------------------------------
# TEST 1: Successful deadline calculation
# ---------------------------------------------------------------------------
def test_1_deadline_calculation_success():
    base_time = datetime(2026, 11, 8, 10, 0, 0, tzinfo=timezone.utc)
    sla_hours = 48
    due = calculate_deadline(sla_hours=sla_hours, priority=ComplaintPriority.MEDIUM.value, base_time=base_time)
    expected = base_time + timedelta(hours=48)
    assert due == expected
    assert due.tzinfo is not None


# ---------------------------------------------------------------------------
# TEST 2: Different complaint categories with distinct SLAs
# ---------------------------------------------------------------------------
def test_2_different_complaint_categories_deadlines():
    base_time = datetime(2026, 11, 8, 12, 0, 0, tzinfo=timezone.utc)
    # Sanitation (24h) vs Pothole (48h) vs Road Trench (72h)
    san_due = calculate_deadline(24, "medium", base_time)
    pothole_due = calculate_deadline(48, "medium", base_time)
    trench_due = calculate_deadline(72, "medium", base_time)

    assert san_due == base_time + timedelta(hours=24)
    assert pothole_due == base_time + timedelta(hours=48)
    assert trench_due == base_time + timedelta(hours=72)
    assert san_due < pothole_due < trench_due


# ---------------------------------------------------------------------------
# TEST 3: Different priority levels (Critical, High, Medium, Low)
# ---------------------------------------------------------------------------
def test_3_priority_based_deadline_multipliers():
    base_time = datetime(2026, 11, 8, 12, 0, 0, tzinfo=timezone.utc)
    sla = 48
    # Critical: 0.5x = 24h
    critical_due = calculate_deadline(sla, ComplaintPriority.CRITICAL.value, base_time)
    # High: 0.75x = 36h
    high_due = calculate_deadline(sla, ComplaintPriority.HIGH.value, base_time)
    # Medium: 1.0x = 48h
    med_due = calculate_deadline(sla, ComplaintPriority.MEDIUM.value, base_time)
    # Low: 1.5x = 72h
    low_due = calculate_deadline(sla, ComplaintPriority.LOW.value, base_time)

    assert critical_due == base_time + timedelta(hours=24)
    assert high_due == base_time + timedelta(hours=36)
    assert med_due == base_time + timedelta(hours=48)
    assert low_due == base_time + timedelta(hours=72)


# ---------------------------------------------------------------------------
# TEST 4: Complaint not yet overdue is NOT escalated
# ---------------------------------------------------------------------------
def test_4_complaint_not_yet_overdue(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9001",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Pending repair",
        description="Freshly submitted complaint well within SLA.",
        ward="Ward 12",
        address="12 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now + timedelta(hours=24),  # Future due date
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    summary = check_and_escalate_overdue_complaints(db_session)
    assert summary["escalated"] == 0

    db_session.refresh(complaint)
    assert complaint.escalation_level == 0
    assert complaint.status == ComplaintStatus.SUBMITTED.value


# ---------------------------------------------------------------------------
# TEST 5: Complaint becomes overdue and is escalated automatically
# ---------------------------------------------------------------------------
def test_5_complaint_becomes_overdue_and_escalated(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9002",
        citizen_id=seed_data["citizen"].id,
        assigned_officer_id=seed_data["officer"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Overdue pothole",
        description="Complaint whose deadline has lapsed.",
        ward="Ward 12",
        address="34 Main St",
        status=ComplaintStatus.ASSIGNED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=3),  # 3 hours overdue
        created_at=now - timedelta(days=2),
        updated_at=now - timedelta(days=2),
    )
    db_session.add(complaint)
    db_session.commit()

    summary = check_and_escalate_overdue_complaints(db_session)
    assert summary["escalated"] >= 1

    db_session.refresh(complaint)
    assert complaint.escalation_level == 1
    assert complaint.status == ComplaintStatus.ESCALATED.value

    # Check escalation event record
    events = get_complaint_escalation_history(db_session, complaint.id)
    assert len(events) == 1
    assert events[0].from_level == 0
    assert events[0].to_level == 1
    assert events[0].trigger_type == "automatic"
    assert events[0].deadline_exceeded_hours >= 3.0


# ---------------------------------------------------------------------------
# TEST 6: Resolved complaint is NOT escalated
# ---------------------------------------------------------------------------
def test_6_resolved_complaint_not_escalated(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9003",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Resolved pothole",
        description="Work was completed.",
        ward="Ward 12",
        address="56 Main St",
        status=ComplaintStatus.RESOLVED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=10),
        resolved_at=now - timedelta(hours=12),
        created_at=now - timedelta(days=3),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    result = escalate_complaint(db_session, complaint.id)
    assert result["success"] is False
    assert result["reason"] == "terminal_status"

    db_session.refresh(complaint)
    assert complaint.escalation_level == 0


# ---------------------------------------------------------------------------
# TEST 7: Cancelled / Rejected complaint is NOT escalated
# ---------------------------------------------------------------------------
def test_7_rejected_complaint_not_escalated(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9004",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Rejected complaint",
        description="Invalid duplicate grievance.",
        ward="Ward 12",
        address="78 Main St",
        status=ComplaintStatus.REJECTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=5),
        created_at=now - timedelta(days=2),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    result = escalate_complaint(db_session, complaint.id)
    assert result["success"] is False
    assert result["reason"] == "terminal_status"

    db_session.refresh(complaint)
    assert complaint.escalation_level == 0


# ---------------------------------------------------------------------------
# TEST 8: Officer to Supervisor escalation (Level 1 -> Level 2)
# ---------------------------------------------------------------------------
def test_8_officer_to_supervisor_escalation(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9005",
        citizen_id=seed_data["citizen"].id,
        assigned_officer_id=seed_data["officer"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Escalate to Supervisor",
        description="Assigned officer missed deadline.",
        ward="Ward 12",
        address="90 Main St",
        status=ComplaintStatus.ESCALATED.value,
        priority=ComplaintPriority.HIGH.value,
        escalation_level=1,
        due_at=now - timedelta(hours=2),
        created_at=now - timedelta(days=3),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    # Create previous level 1 event so history is valid
    prev_event = EscalationEvent(
        complaint_id=complaint.id,
        from_level=0,
        to_level=1,
        reason="Initial deadline breached",
        escalated_to_id=seed_data["officer"].id,
        trigger_type="automatic",
        created_at=now - timedelta(days=1),
    )
    db_session.add(prev_event)
    db_session.commit()

    result = escalate_complaint(db_session, complaint.id)
    assert result["success"] is True
    assert result["from_level"] == 1
    assert result["to_level"] == 2
    assert result["assigned_to_id"] == seed_data["supervisor"].id

    db_session.refresh(complaint)
    assert complaint.escalation_level == 2
    assert complaint.assigned_officer_id == seed_data["supervisor"].id


# ---------------------------------------------------------------------------
# TEST 9: Supervisor to Higher Authority escalation (Level 2 -> Level 3)
# ---------------------------------------------------------------------------
def test_9_supervisor_to_higher_authority_escalation(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9006",
        citizen_id=seed_data["citizen"].id,
        assigned_officer_id=seed_data["supervisor"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Escalate to Admin Commissioner",
        description="Supervisor also missed SLA extension.",
        ward="Ward 12",
        address="100 Main St",
        status=ComplaintStatus.ESCALATED.value,
        priority=ComplaintPriority.CRITICAL.value,
        escalation_level=2,
        due_at=now - timedelta(hours=1),
        created_at=now - timedelta(days=5),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    result = escalate_complaint(db_session, complaint.id)
    assert result["success"] is True
    assert result["from_level"] == 2
    assert result["to_level"] == 3
    assert result["assigned_to_id"] == seed_data["admin"].id

    db_session.refresh(complaint)
    assert complaint.escalation_level == 3
    assert complaint.assigned_officer_id == seed_data["admin"].id


# ---------------------------------------------------------------------------
# TEST 10: Maximum escalation level prevented
# ---------------------------------------------------------------------------
def test_10_maximum_escalation_level_prevented(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9007",
        citizen_id=seed_data["citizen"].id,
        assigned_officer_id=seed_data["admin"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Max level reached",
        description="Complaint already at top authority.",
        ward="Ward 12",
        address="110 Main St",
        status=ComplaintStatus.ESCALATED.value,
        priority=ComplaintPriority.CRITICAL.value,
        escalation_level=3,  # Already at MAX level
        due_at=now - timedelta(hours=10),
        created_at=now - timedelta(days=6),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    result = escalate_complaint(db_session, complaint.id, max_level=3)
    assert result["success"] is False
    assert result["reason"] == "already_max_level"
    assert result["level"] == 3


# ---------------------------------------------------------------------------
# TEST 11: Duplicate escalation prevention at same stage
# ---------------------------------------------------------------------------
def test_11_duplicate_escalation_prevention(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9008",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Duplicate prevention test",
        description="Testing that level 1 cannot be escalated twice.",
        ward="Ward 12",
        address="120 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=1),
        created_at=now - timedelta(days=1),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    # First escalation to Level 1
    first_res = escalate_complaint(db_session, complaint.id)
    assert first_res["success"] is True
    assert first_res["to_level"] == 1

    # Simulate complaint staying or reverting to level 0 and attempting level 1 again
    complaint.escalation_level = 0
    db_session.commit()

    # Second attempt to escalate to Level 1
    second_res = escalate_complaint(db_session, complaint.id)
    assert second_res["success"] is False
    assert second_res["reason"] == "duplicate_escalation_prevented"

    # Verify only 1 event exists for level 1
    events = (
        db_session.query(EscalationEvent)
        .filter(EscalationEvent.complaint_id == complaint.id, EscalationEvent.to_level == 1)
        .all()
    )
    assert len(events) == 1


# ---------------------------------------------------------------------------
# TEST 12: Repeated scheduler execution is idempotent
# ---------------------------------------------------------------------------
def test_12_repeated_scheduler_executions(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9009",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Repeated checker test",
        description="Testing scheduler idempotency.",
        ward="Ward 12",
        address="130 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=4),
        created_at=now - timedelta(days=2),
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    # First run escalates
    run1 = check_and_escalate_overdue_complaints(db_session)
    assert run1["escalated"] >= 1

    # Second run immediately after: due_at has been extended, so complaint is not overdue anymore
    run2 = check_and_escalate_overdue_complaints(db_session)
    assert run2["escalated"] == 0

    # Third run: still not overdue
    run3 = check_and_escalate_overdue_complaints(db_session)
    assert run3["escalated"] == 0

    # Total events for this complaint remains 1
    events = get_complaint_escalation_history(db_session, complaint.id)
    assert len(events) == 1


# ---------------------------------------------------------------------------
# TEST 13: Database-level uniqueness prevents simultaneous duplicate events
# ---------------------------------------------------------------------------
def test_13_simultaneous_escalation_database_uniqueness(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9010",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="DB constraint test",
        description="Testing raw database unique constraint.",
        ward="Ward 12",
        address="140 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=1),
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    # Add first event
    e1 = EscalationEvent(
        complaint_id=complaint.id,
        from_level=0,
        to_level=1,
        reason="First concurrent thread",
        created_at=now,
    )
    db_session.add(e1)
    db_session.commit()

    # Attempting to add second event for identical complaint_id and to_level triggers IntegrityError
    e2 = EscalationEvent(
        complaint_id=complaint.id,
        from_level=0,
        to_level=1,
        reason="Second concurrent thread",
        created_at=now,
    )
    db_session.add(e2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


# ---------------------------------------------------------------------------
# TEST 14: Unauthorized escalation attempts rejected
# ---------------------------------------------------------------------------
def test_14_unauthorized_escalation_attempts(client, seed_data):
    citizen_headers = auth_header_for_user(seed_data["citizen"])

    # 1. Citizen cannot trigger manual checker
    res1 = client.post("/api/v1/escalation/trigger-check", headers=citizen_headers)
    assert res1.status_code == 403

    # 2. Citizen cannot create escalation rules
    res2 = client.post(
        "/api/v1/escalation/rules",
        json={
            "escalation_level": 1,
            "trigger_hours": 24,
            "target_role": "supervisor",
        },
        headers=citizen_headers,
    )
    assert res2.status_code == 403

    # 3. Citizen cannot manually escalate a complaint
    res3 = client.post(
        "/api/v1/complaints/1/escalate",
        json={"reason": "Citizen trying to escalate"},
        headers=citizen_headers,
    )
    assert res3.status_code == 403


# ---------------------------------------------------------------------------
# TEST 15: Missing authority recipient handled gracefully
# ---------------------------------------------------------------------------
def test_15_missing_authority_recipient(db_session, seed_data):
    now = datetime.now(timezone.utc)
    # Deactivate or remove any admins/supervisors temporarily or use level 4 where no user exists
    complaint = Complaint(
        complaint_number="CIVIC-2026-9011",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Missing authority recipient",
        description="Testing escalation when no user with role exists.",
        ward="Ward 12",
        address="150 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=2),
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    # Create a rule pointing to a role that does not exist in seed_data
    fake_rule = EscalationRule(
        department_id=seed_data["dept"].id,
        escalation_level=1,
        trigger_hours=12,
        target_role="non_existent_role",
        is_active=True,
    )
    db_session.add(fake_rule)
    db_session.commit()

    # Escalation should complete without exception, setting assigned_to_id as None
    result = escalate_complaint(db_session, complaint.id)
    assert result["success"] is True
    assert result["assigned_to_id"] is None

    db_session.refresh(complaint)
    assert complaint.escalation_level == 1


# ---------------------------------------------------------------------------
# TEST 16: Notification creation on escalation
# ---------------------------------------------------------------------------
def test_16_notification_creation_on_escalation(db_session, seed_data):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9012",
        citizen_id=seed_data["citizen"].id,
        assigned_officer_id=seed_data["officer"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Pothole notification test",
        description="Verify in-app alerts on escalation.",
        ward="Ward 12",
        address="160 Main St",
        status=ComplaintStatus.ASSIGNED.value,
        priority=ComplaintPriority.HIGH.value,
        escalation_level=0,
        due_at=now - timedelta(hours=2),
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    result = escalate_complaint(db_session, complaint.id)
    assert result["success"] is True

    # Check notification for citizen
    citizen_notif = (
        db_session.query(Notification)
        .filter(Notification.user_id == seed_data["citizen"].id, Notification.complaint_id == complaint.id)
        .first()
    )
    assert citizen_notif is not None
    assert "CIVIC-2026-9012" in citizen_notif.title or "CIVIC-2026-9012" in citizen_notif.message

    # Check notification for newly assigned supervisor (Level 1 default role is officer, or supervisor)
    assigned_id = result["assigned_to_id"]
    if assigned_id:
        officer_notif = (
            db_session.query(Notification)
            .filter(Notification.user_id == assigned_id, Notification.complaint_id == complaint.id)
            .first()
        )
        assert officer_notif is not None
        assert "Escalation" in officer_notif.title


# ---------------------------------------------------------------------------
# TEST 17: Escalation history retrieval via API
# ---------------------------------------------------------------------------
def test_17_escalation_history_retrieval(client, seed_data, db_session):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9013",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="History API test",
        description="Verify history retrieval via API.",
        ward="Ward 12",
        address="170 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=2),
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()

    # Escalate complaint
    escalate_complaint(db_session, complaint.id, reason="Testing history endpoint")

    citizen_headers = auth_header_for_user(seed_data["citizen"])
    other_citizen_headers = auth_header_for_user(seed_data["other_citizen"])
    admin_headers = auth_header_for_user(seed_data["admin"])

    # 1. Citizen owner can view
    res1 = client.get(f"/api/v1/complaints/{complaint.id}/escalations", headers=citizen_headers)
    assert res1.status_code == 200
    events = res1.json()
    assert len(events) == 1
    assert events[0]["from_level"] == 0
    assert events[0]["to_level"] == 1

    # 2. Admin can view
    res2 = client.get(f"/api/v1/complaints/{complaint.id}/escalations", headers=admin_headers)
    assert res2.status_code == 200

    # 3. Another unrelated citizen is rejected (403)
    res3 = client.get(f"/api/v1/complaints/{complaint.id}/escalations", headers=other_citizen_headers)
    assert res3.status_code == 403


# ---------------------------------------------------------------------------
# TEST 18: Database rollback on failure
# ---------------------------------------------------------------------------
def test_18_database_rollback_after_failure(db_session, seed_data, monkeypatch):
    now = datetime.now(timezone.utc)
    complaint = Complaint(
        complaint_number="CIVIC-2026-9014",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Rollback test",
        description="Testing transactional safety.",
        ward="Ward 12",
        address="180 Main St",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.MEDIUM.value,
        escalation_level=0,
        due_at=now - timedelta(hours=2),
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()
    target_id = complaint.id

    # Monkeypatch db_session.commit to simulate database connection/IO failure during transaction
    original_commit = db_session.commit

    def broken_commit():
        raise RuntimeError("Simulated Database Disk I/O Failure")

    monkeypatch.setattr(db_session, "commit", broken_commit)

    result = escalate_complaint(db_session, target_id)
    assert result["success"] is False
    assert result["reason"] == "database_error"

    # Restore commit and verify no stray escalation event was committed to DB
    monkeypatch.setattr(db_session, "commit", original_commit)

    events = (
        db_session.query(EscalationEvent)
        .filter(EscalationEvent.complaint_id == target_id)
        .all()
    )
    assert len(events) == 0
