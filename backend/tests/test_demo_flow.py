import pytest
from datetime import datetime, timedelta, timezone

from backend.models.complaint import Complaint
from backend.models.escalation import EscalationEvent
from backend.models.notification import Notification
from backend.models.enums import UserRole, ComplaintStatus, ComplaintPriority
from backend.services.deadline_service import is_overdue
from backend.services.escalation_service import (
    check_and_escalate_overdue_complaints,
    get_complaint_escalation_history,
)
from backend.services.notification_service import get_user_notifications


def test_complete_15_step_demonstration_scenario(db_session, seed_data):
    """
    Automated verification of the exact 15-step demonstration scenario
    required by the project guide.
    """
    now = datetime.now(timezone.utc)

    # 1. Create a complaint about a pothole
    complaint = Complaint(
        complaint_number="DEMO-TEST-15STEP",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Pothole demonstration test",
        description="Pothole grievance testing 15 step cycle.",
        ward="Ward 12",
        address="Central Road",
        status=ComplaintStatus.SUBMITTED.value,
        priority=ComplaintPriority.HIGH.value,
        escalation_level=0,
        due_at=now + timedelta(hours=48),
        created_at=now,
        updated_at=now,
    )
    db_session.add(complaint)
    db_session.commit()
    assert complaint.id is not None

    # 2. Assign the complaint to an officer
    complaint.assigned_officer_id = seed_data["officer"].id
    complaint.status = ComplaintStatus.ASSIGNED.value
    db_session.commit()
    assert complaint.assigned_officer_id == seed_data["officer"].id

    # 3. Configure short test deadline
    complaint.due_at = now - timedelta(hours=3)
    db_session.commit()

    # 4. Check deadline expired
    assert is_overdue(complaint.due_at, now)

    # 5. Overdue checker detects complaint
    summary1 = check_and_escalate_overdue_complaints(db_session)
    assert summary1["escalated"] >= 1

    # 6. Escalated to supervisor / next authority
    db_session.refresh(complaint)
    assert complaint.escalation_level == 1
    assert complaint.status == ComplaintStatus.ESCALATED.value

    # 7. In-app notification received
    assigned_id = complaint.assigned_officer_id
    notifs = get_user_notifications(db_session, user_id=assigned_id)
    assert len(notifs) >= 1

    # 8. Escalation event stored in database
    events = get_complaint_escalation_history(db_session, complaint.id)
    assert len(events) == 1
    assert events[0].from_level == 0
    assert events[0].to_level == 1

    # 9. Next deadline expires
    complaint.due_at = now - timedelta(hours=1)
    db_session.commit()

    # 10. Moves to configured higher authority
    summary2 = check_and_escalate_overdue_complaints(db_session)
    assert summary2["escalated"] >= 1

    # 11. Another escalation event recorded
    db_session.refresh(complaint)
    events2 = get_complaint_escalation_history(db_session, complaint.id)
    assert len(events2) == 2
    assert events2[1].from_level == 1
    assert events2[1].to_level == 2

    # 12. Run checker again
    summary3 = check_and_escalate_overdue_complaints(db_session)

    # 13. Verify no duplicate escalation events
    events3 = get_complaint_escalation_history(db_session, complaint.id)
    assert len(events3) == 2

    # 14. Resolve complaint
    complaint.status = ComplaintStatus.RESOLVED.value
    complaint.resolved_at = now
    db_session.commit()

    # 15. Verify resolved complaints are not escalated even if due date is old
    complaint.due_at = now - timedelta(days=10)
    db_session.commit()
    check_and_escalate_overdue_complaints(db_session)
    events_final = get_complaint_escalation_history(db_session, complaint.id)
    assert len(events_final) == 2
    assert complaint.status == ComplaintStatus.RESOLVED.value
