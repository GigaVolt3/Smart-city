"""Seed a realistic demo municipality.

Guarded: refuses to run against a populated database unless --force is passed.
"""

import random
from datetime import datetime, timedelta, timezone

from PIL import Image, ImageDraw

from backend.core.database import Base, SessionLocal, engine
from backend.core.security import hash_password
from backend.models.category import ComplaintCategory
from backend.models.complaint import Complaint, ComplaintAttachment
from backend.models.department import Department
from backend.models.enums import ComplaintPriority, ComplaintStatus, UserRole
from backend.models.escalation import EscalationEvent, EscalationRule
from backend.models.notification import Notification
from backend.models.status_history import StatusHistory
from backend.models.user import User
from backend.services.uploads import uploads_root

YEAR = datetime.now(timezone.utc).year
DEMO_PASSWORD = "DemoPass1!"

WARDS = [
    ("Ward 12 (Indiranagar)", 12.9719, 77.6412),
    ("Ward 15 (Domlur)", 12.9609, 77.6387),
    ("Ward 8 (Koramangala)", 12.9352, 77.6245),
    ("Ward 3 (Rajajinagar)", 12.9916, 77.5559),
    ("Ward 22 (HSR Layout)", 12.9116, 77.6474),
    ("Ward 5 (Jayanagar)", 12.9308, 77.5838),
    ("Ward 18 (Whitefield)", 12.9698, 77.7500),
    ("Ward 1 (Malleshwaram)", 13.0035, 77.5647),
    ("Ward 9 (BTM Layout)", 12.9166, 77.6101),
    ("Ward 14 (Hebbal)", 13.0358, 77.5970),
]

ROADS = [
    "100 Feet Road",
    "12th Main Road",
    "Old Airport Road",
    "Sarjapur Road",
    "80 Feet Road",
    "CMH Road",
    "Bannerghatta Main Road",
    "Hosur Road service lane",
    "Mysore Road",
    "Outer Ring Road",
]

PLACES = [
    "the metro station",
    "the government school gate",
    "the bus stand",
    "the vegetable market",
    "the primary health centre",
    "the community park",
    "the BBMP ward office",
    "the railway underpass",
]

CATEGORY_TEMPLATES = {
    "POTHOLE": (
        "Deep pothole on {road}",
        "A large crater has formed on {road} near {place}. Two-wheelers are swerving into traffic to avoid it and the surface is worsening after rain.",
    ),
    "DAMAGED_ROAD": (
        "Broken asphalt near {place}",
        "The road surface has cracked and sunk near {place}. Loose gravel is being thrown onto footpath and pedestrians are tripping.",
    ),
    "GARBAGE_ACCUMULATION": (
        "Overflowing garbage bin at {place}",
        "The community waste bin near {place} has not been cleared for several days. Waste is spilling onto the street and attracting stray dogs.",
    ),
    "DEAD_ANIMAL": (
        "Dead animal carcass on {road}",
        "A carcass is lying beside {road} near {place}. It is creating a strong odour and a public health risk for nearby homes.",
    ),
    "STREETLIGHT_BROKEN": (
        "Streetlights dark on {road}",
        "Four consecutive streetlights on {road} are not working. The stretch near {place} is completely dark after 7 PM and unsafe for pedestrians.",
    ),
    "EXPOSED_WIRING": (
        "Sparking electric pole near {place}",
        "An electrical junction box near {place} has an exposed live wire and is sparking intermittently. Children play next to this pole every evening.",
    ),
    "WATER_LEAKAGE": (
        "Water pipeline leaking at {place}",
        "A main water line is leaking continuously near {place}. Potable water is flooding the road and the supply pressure in nearby homes has dropped.",
    ),
    "CONTAMINATED_WATER": (
        "Discoloured tap water near {place}",
        "Tap water supplied to homes around {place} is muddy and smells foul. Residents are worried about waterborne illness and are buying bottled water.",
    ),
    "DRAIN_BLOCKED": (
        "Blocked storm drain flooding {road}",
        "The storm drain along {road} is choked with silt and plastic. Even light rain floods the street near {place} knee-deep.",
    ),
    "OPEN_MANHOLE": (
        "Missing manhole cover near {place}",
        "A chamber cover is missing beside {place}, leaving an open pit on the footpath. School children use this route every morning.",
    ),
}


def _password_hash() -> str:
    return hash_password(DEMO_PASSWORD)


def seed_departments(db) -> dict[str, Department]:
    data = [
        ("Roads & Infrastructure", "ROADS", "Arterial roads, footpaths, bridges and pothole patching", "roads@demo.civicai", "+91-80-2222-1001"),
        ("Solid Waste & Sanitation", "SAN", "Garbage collection, street sweeping and dump yards", "sanitation@demo.civicai", "+91-80-2222-1002"),
        ("Street Lighting & Electrical", "ELEC", "Streetlights, high-mast lamps and electrical hazards", "electrical@demo.civicai", "+91-80-2222-1003"),
        ("Water Supply & Sewerage", "WATER", "Drinking water supply, pipeline bursts and sewage", "water@demo.civicai", "+91-80-2222-1004"),
        ("Storm Water Drains & Flood Control", "DRAIN", "Storm drains, manholes and flood mitigation", "drains@demo.civicai", "+91-80-2222-1005"),
    ]
    departments = {}
    for name, code, description, email, phone in data:
        dept = db.query(Department).filter(Department.code == code).first()
        if not dept:
            dept = Department(
                name=name,
                code=code,
                description=description,
                contact_email=email,
                contact_phone=phone,
            )
            db.add(dept)
            db.flush()
            print(f"  + Department: {name} ({code})")
        departments[code] = dept
    db.commit()
    return departments


def seed_categories(db, departments) -> dict[str, ComplaintCategory]:
    data = [
        ("ROADS", "Pothole Repair", "POTHOLE", "Potholes and craters on carriageways", 48, ComplaintPriority.MEDIUM),
        ("ROADS", "Damaged Road Surface", "DAMAGED_ROAD", "Cracked asphalt, trenches and broken footpaths", 72, ComplaintPriority.MEDIUM),
        ("SAN", "Garbage Accumulation", "GARBAGE_ACCUMULATION", "Uncollected waste and overflowing bins", 24, ComplaintPriority.HIGH),
        ("SAN", "Dead Animal Disposal", "DEAD_ANIMAL", "Carcass requiring safe sanitary disposal", 8, ComplaintPriority.CRITICAL),
        ("ELEC", "Streetlight Not Working", "STREETLIGHT_BROKEN", "Malfunctioning streetlights and dark stretches", 24, ComplaintPriority.MEDIUM),
        ("ELEC", "Exposed Wiring / Sparking", "EXPOSED_WIRING", "Live cables, sparking poles and open junction boxes", 4, ComplaintPriority.CRITICAL),
        ("WATER", "Pipeline Water Leakage", "WATER_LEAKAGE", "Burst mains and leaking valves", 24, ComplaintPriority.HIGH),
        ("WATER", "Contaminated Water Supply", "CONTAMINATED_WATER", "Discoloured, turbid or foul tap water", 12, ComplaintPriority.CRITICAL),
        ("DRAIN", "Blocked Storm Drain", "DRAIN_BLOCKED", "Clogged drains and water logging", 48, ComplaintPriority.HIGH),
        ("DRAIN", "Open / Missing Manhole", "OPEN_MANHOLE", "Uncovered manholes and broken chamber slabs", 4, ComplaintPriority.CRITICAL),
    ]
    categories = {}
    for dept_code, name, code, description, sla, priority in data:
        category = db.query(ComplaintCategory).filter(ComplaintCategory.code == code).first()
        if not category:
            category = ComplaintCategory(
                department_id=departments[dept_code].id,
                name=name,
                code=code,
                description=description,
                sla_hours=sla,
                priority_default=priority.value,
            )
            db.add(category)
            db.flush()
            print(f"  + Category: {name} ({code})")
        categories[code] = category
    db.commit()
    return categories


def seed_users(db, departments) -> dict[str, User]:
    password = _password_hash()
    data = [
        ("citizen@demo.civicai", "Ramesh Kumar", "+91-98765-43210", UserRole.CITIZEN, "Ward 12 (Indiranagar)", None),
        ("officer@demo.civicai", "Priya Sharma", "+91-98765-43211", UserRole.OFFICER, "Ward 12 (Indiranagar)", "ROADS"),
        ("supervisor@demo.civicai", "Dr. Anand Rao", "+91-98765-43212", UserRole.SUPERVISOR, "East Zone HQ", "ROADS"),
        ("admin@demo.civicai", "Chief Municipal Administrator", "+91-98765-43213", UserRole.ADMIN, "Municipal Corporation Central", None),
        ("meera.officer@demo.civicai", "Meera Iyer", "+91-98765-43214", UserRole.OFFICER, "Ward 12 (Indiranagar)", "SAN"),
        ("vikram.officer@demo.civicai", "Vikram Singh", "+91-98765-43215", UserRole.OFFICER, "Ward 14 (Hebbal)", "ELEC"),
        ("fatima.officer@demo.civicai", "Fatima Begum", "+91-98765-43216", UserRole.OFFICER, "Ward 22 (HSR Layout)", "WATER"),
        ("joseph.officer@demo.civicai", "Joseph Thomas", "+91-98765-43217", UserRole.OFFICER, "Ward 15 (Domlur)", "DRAIN"),
        ("kavita.supervisor@demo.civicai", "Kavita Menon", "+91-98765-43218", UserRole.SUPERVISOR, "East Zone HQ", "SAN"),
        ("suresh.supervisor@demo.civicai", "Suresh Gowda", "+91-98765-43219", UserRole.SUPERVISOR, "South Zone HQ", "WATER"),
    ]
    users: dict[str, User] = {}
    for email, name, phone, role, ward, dept_code in data:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            user = User(
                email=email,
                full_name=name,
                phone_number=phone,
                role=role.value,
                ward=ward,
                department_id=departments[dept_code].id if dept_code else None,
                hashed_password=password,
                is_active=True,
            )
            db.add(user)
            db.flush()
            print(f"  + User: {name} ({role.value})")
        users[email] = user
    db.commit()
    return users


def seed_escalation_rules(db):
    rules = [
        (1, 0, UserRole.SUPERVISOR.value),
        (2, 24, UserRole.ADMIN.value),
        (3, 72, UserRole.ADMIN.value),
    ]
    for level, hours, target in rules:
        existing = (
            db.query(EscalationRule)
            .filter(
                EscalationRule.escalation_level == level,
                EscalationRule.department_id.is_(None),
                EscalationRule.category_id.is_(None),
            )
            .first()
        )
        if not existing:
            db.add(
                EscalationRule(
                    escalation_level=level,
                    trigger_hours=hours,
                    target_role=target,
                )
            )
            print(f"  + Escalation rule: L{level} after {hours}h -> {target}")
    db.commit()


def _history(
    db,
    complaint: Complaint,
    previous: str | None,
    new: str,
    actor_id: int | None,
    comments: str,
    at: datetime,
):
    db.add(
        StatusHistory(
            complaint_id=complaint.id,
            previous_status=previous,
            new_status=new,
            changed_by_id=actor_id,
            comments=comments,
            created_at=at,
        )
    )


def seed_base_complaints(db, departments, categories, users):
    now = datetime.now(timezone.utc)
    citizen = users["citizen@demo.civicai"]
    officer = users["officer@demo.civicai"]
    supervisor = users["supervisor@demo.civicai"]
    data = [
        {
            "complaint_number": f"CIVIC-{YEAR}-0001",
            "category": "POTHOLE",
            "dept": "ROADS",
            "title": "Large crater pothole on 100ft Road junction",
            "description": "Deep pothole measuring approximately 2 feet wide right near the metro pillar junction. Vehicles are braking abruptly and two-wheelers have already had minor collisions.",
            "ward": "Ward 12 (Indiranagar)",
            "address": "Opposite Metro Pillar 142, 100 Feet Road, HAL 2nd Stage",
            "landmark": "Near Coffee Day Signal",
            "latitude": 12.9716,
            "longitude": 77.6412,
            "status": ComplaintStatus.IN_PROGRESS,
            "priority": ComplaintPriority.HIGH,
            "escalation_level": 0,
            "due_offset_hours": 36,
            "created_hours_ago": 12,
            "assigned": officer.id,
            "history": [
                (None, ComplaintStatus.SUBMITTED, citizen.id, "Complaint submitted with location coordinates", 12),
                (ComplaintStatus.SUBMITTED, ComplaintStatus.ASSIGNED, supervisor.id, "Assigned to Ward Assistant Engineer Priya Sharma", 8),
                (ComplaintStatus.ASSIGNED, ComplaintStatus.IN_PROGRESS, officer.id, "Inspection complete; asphalt mix dispatched for hot-pour filling", 2),
            ],
        },
        {
            "complaint_number": f"CIVIC-{YEAR}-0002",
            "category": "GARBAGE_ACCUMULATION",
            "dept": "SAN",
            "title": "Overflowing waste dumpster attracting stray dogs",
            "description": "The community waste bin has not been cleared for 3 consecutive days. Refuse has spilled onto the roadway blocking the walking path.",
            "ward": "Ward 12 (Indiranagar)",
            "address": "7th Cross, 4th Main, Defence Colony",
            "landmark": "Adjacent to Public Park gate 2",
            "latitude": 12.9754,
            "longitude": 77.6450,
            "status": ComplaintStatus.SUBMITTED,
            "priority": ComplaintPriority.HIGH,
            "escalation_level": 0,
            "due_offset_hours": 18,
            "created_hours_ago": 6,
            "assigned": None,
            "history": [
                (None, ComplaintStatus.SUBMITTED, citizen.id, "Citizen reported garbage accumulation", 6),
            ],
        },
        {
            "complaint_number": f"CIVIC-{YEAR}-0003",
            "category": "OPEN_MANHOLE",
            "dept": "DRAIN",
            "title": "Broken cement cover on footpath drain",
            "description": "Missing chamber slab creating an open 5-foot pit on the walking path next to the school bus stand. High risk of pedestrian injury.",
            "ward": "Ward 15 (Domlur)",
            "address": "Airport Road service lane, Domlur",
            "landmark": "Near National Public School bus stop",
            "latitude": 12.9609,
            "longitude": 77.6387,
            "status": ComplaintStatus.SUBMITTED,
            "priority": ComplaintPriority.CRITICAL,
            "escalation_level": 0,
            "due_offset_hours": 2,
            "created_hours_ago": 2,
            "assigned": None,
            "history": [
                (None, ComplaintStatus.SUBMITTED, citizen.id, "Critical open manhole alert submitted", 2),
            ],
        },
        {
            "complaint_number": f"CIVIC-{YEAR}-0004",
            "category": "STREETLIGHT_BROKEN",
            "dept": "ELEC",
            "title": "Series of 4 streetlights dark for 2 nights",
            "description": "The entire stretch of the residential lane is completely pitch dark after 7 PM. Senior citizens are unable to walk safely.",
            "ward": "Ward 12 (Indiranagar)",
            "address": "12th B Main, HAL 2nd Stage",
            "landmark": "Behind BDA Complex",
            "latitude": 12.9698,
            "longitude": 77.6391,
            "status": ComplaintStatus.RESOLVED,
            "priority": ComplaintPriority.MEDIUM,
            "escalation_level": 0,
            "due_offset_hours": -10,
            "created_hours_ago": 28,
            "resolved_hours_ago": 4,
            "assigned": officer.id,
            "history": [
                (None, ComplaintStatus.SUBMITTED, citizen.id, "Citizen grievance logged", 28),
                (ComplaintStatus.SUBMITTED, ComplaintStatus.IN_PROGRESS, officer.id, "Linesman deployed to inspect feeder pillar fuse", 14),
                (ComplaintStatus.IN_PROGRESS, ComplaintStatus.RESOLVED, officer.id, "Blown phase fuse replaced and LED driver checked; all 4 lights operational", 4),
            ],
        },
    ]

    for item in data:
        if db.query(Complaint).filter(Complaint.complaint_number == item["complaint_number"]).first():
            continue
        created_at = now - timedelta(hours=item["created_hours_ago"])
        complaint = Complaint(
            complaint_number=item["complaint_number"],
            citizen_id=citizen.id,
            assigned_officer_id=item["assigned"],
            department_id=departments[item["dept"]].id,
            category_id=categories[item["category"]].id,
            title=item["title"],
            description=item["description"],
            ward=item["ward"],
            address=item["address"],
            landmark=item["landmark"],
            latitude=item["latitude"],
            longitude=item["longitude"],
            status=item["status"].value,
            priority=item["priority"].value,
            escalation_level=item["escalation_level"],
            due_at=now + timedelta(hours=item["due_offset_hours"]),
            resolved_at=(
                now - timedelta(hours=item["resolved_hours_ago"])
                if item.get("resolved_hours_ago")
                else None
            ),
            created_at=created_at,
            updated_at=now - timedelta(hours=2),
        )
        db.add(complaint)
        db.flush()
        for previous, new, actor, comments, hours_ago in item["history"]:
            _history(
                db,
                complaint,
                previous.value if previous else None,
                new.value,
                actor,
                comments,
                now - timedelta(hours=hours_ago),
            )
        print(f"  + Complaint: {complaint.complaint_number} — {complaint.title}")
    db.commit()


def seed_generated_complaints(db, departments, categories, users):
    rng = random.Random(20261110)
    now = datetime.now(timezone.utc)
    citizen = users["citizen@demo.civicai"]
    dept_staff: dict[str, list[User]] = {}
    for code, dept in departments.items():
        dept_staff[code] = (
            db.query(User)
            .filter(User.department_id == dept.id, User.role == UserRole.OFFICER.value)
            .all()
        )
    supervisors = (
        db.query(User).filter(User.role == UserRole.SUPERVISOR.value).all()
    )
    admins = db.query(User).filter(User.role == UserRole.ADMIN.value).all()

    codes = list(categories.keys())
    generated = 0
    for index in range(5, 49):
        number = f"CIVIC-{YEAR}-{index:04d}"
        if db.query(Complaint).filter(Complaint.complaint_number == number).first():
            continue

        code = rng.choice(codes)
        category = categories[code]
        dept = departments[category.department.code]
        ward_name, ward_lat, ward_lng = rng.choice(WARDS)
        road = rng.choice(ROADS)
        place = rng.choice(PLACES)
        title_template, desc_template = CATEGORY_TEMPLATES[code]
        title = title_template.format(road=road, place=place)
        description = desc_template.format(road=road, place=place)

        age_days = rng.uniform(0.15, 78.0)
        created_at = now - timedelta(days=age_days)

        if age_days > 30:
            status = rng.choices(
                [
                    ComplaintStatus.RESOLVED,
                    ComplaintStatus.REJECTED,
                    ComplaintStatus.IN_PROGRESS,
                    ComplaintStatus.ESCALATED,
                ],
                weights=[7, 1, 1, 1],
            )[0]
        elif age_days > 8:
            status = rng.choices(
                [
                    ComplaintStatus.RESOLVED,
                    ComplaintStatus.IN_PROGRESS,
                    ComplaintStatus.ASSIGNED,
                    ComplaintStatus.ESCALATED,
                ],
                weights=[4, 3, 2, 1],
            )[0]
        else:
            status = rng.choices(
                [
                    ComplaintStatus.SUBMITTED,
                    ComplaintStatus.ASSIGNED,
                    ComplaintStatus.IN_PROGRESS,
                    ComplaintStatus.ESCALATED,
                ],
                weights=[3, 3, 2, 2],
            )[0]

        priority = ComplaintPriority(category.priority_default)
        if rng.random() < 0.18:
            priority = ComplaintPriority.CRITICAL
        due_at = created_at + timedelta(hours=category.sla_hours)

        officer = rng.choice(dept_staff[category.department.code]) if dept_staff[category.department.code] else None
        assigned_id = officer.id if status != ComplaintStatus.SUBMITTED and officer else None

        resolved_at = None
        history = [(None, ComplaintStatus.SUBMITTED.value, citizen.id, "Grievance submitted by citizen", created_at)]

        if status == ComplaintStatus.RESOLVED:
            resolution_offset = timedelta(
                hours=rng.uniform(1.0, category.sla_hours * 1.8)
            )
            resolved_at = min(now - timedelta(hours=1), created_at + resolution_offset)
            if assigned_id:
                history.append(
                    (
                        ComplaintStatus.SUBMITTED.value,
                        ComplaintStatus.ASSIGNED.value,
                        supervisors[0].id if supervisors else None,
                        f"Assigned to {officer.full_name}",
                        created_at + timedelta(hours=1),
                    )
                )
                history.append(
                    (
                        ComplaintStatus.ASSIGNED.value,
                        ComplaintStatus.IN_PROGRESS.value,
                        assigned_id,
                        "Field team dispatched to inspect the site",
                        created_at + timedelta(hours=3),
                    )
                )
            history.append(
                (
                    ComplaintStatus.IN_PROGRESS.value,
                    ComplaintStatus.RESOLVED.value,
                    assigned_id,
                    "Work completed and verified by field officer",
                    resolved_at,
                )
            )
        elif status == ComplaintStatus.REJECTED:
            history.append(
                (
                    ComplaintStatus.SUBMITTED.value,
                    ComplaintStatus.REJECTED.value,
                    supervisors[0].id if supervisors else None,
                    "Rejected after site inspection: issue falls outside municipal jurisdiction",
                    created_at + timedelta(hours=rng.uniform(2, 20)),
                )
            )
        elif status in (ComplaintStatus.ASSIGNED, ComplaintStatus.IN_PROGRESS):
            if assigned_id:
                history.append(
                    (
                        ComplaintStatus.SUBMITTED.value,
                        ComplaintStatus.ASSIGNED.value,
                        supervisors[0].id if supervisors else None,
                        f"Assigned to {officer.full_name}",
                        created_at + timedelta(hours=1),
                    )
                )
            if status == ComplaintStatus.IN_PROGRESS:
                history.append(
                    (
                        ComplaintStatus.ASSIGNED.value,
                        ComplaintStatus.IN_PROGRESS.value,
                        assigned_id,
                        "Inspection complete; repair work scheduled",
                        created_at + timedelta(hours=4),
                    )
                )

        complaint = Complaint(
            complaint_number=number,
            citizen_id=citizen.id,
            assigned_officer_id=assigned_id,
            department_id=dept.id,
            category_id=category.id,
            title=title,
            description=description,
            ward=ward_name,
            address=f"{road}, near {place}",
            landmark=place,
            latitude=round(ward_lat + rng.uniform(-0.012, 0.012), 6),
            longitude=round(ward_lng + rng.uniform(-0.012, 0.012), 6),
            status=status.value,
            priority=priority.value,
            escalation_level=0,
            due_at=due_at,
            resolved_at=resolved_at,
            created_at=created_at,
            updated_at=resolved_at or (created_at + timedelta(hours=4)),
        )

        overdue_hours = 0.0
        if status not in (ComplaintStatus.RESOLVED, ComplaintStatus.REJECTED):
            overdue_hours = max(0.0, (now - due_at).total_seconds() / 3600.0)

        # Pre-apply escalation levels so the background engine is idempotent.
        level = 0
        if overdue_hours >= 72:
            level = 3
        elif overdue_hours >= 24:
            level = 2
        elif overdue_hours > 0:
            level = 1
        if level:
            status = ComplaintStatus.ESCALATED
            complaint.status = status.value

        db.add(complaint)
        db.flush()

        for previous, new, actor, comments, at in history:
            _history(db, complaint, previous, new, actor, comments, at)

        for rule_level in range(1, level + 1):
            triggered_at = due_at + timedelta(hours=[0, 24, 72][rule_level - 1])
            recipient = (
                (supervisors[0] if supervisors else None)
                if rule_level == 1
                else (admins[0] if admins else None)
            )
            db.add(
                EscalationEvent(
                    complaint_id=complaint.id,
                    from_level=rule_level - 1,
                    to_level=rule_level,
                    reason=f"SLA deadline exceeded; auto-escalated to level {rule_level}",
                    escalated_to_id=recipient.id if recipient else None,
                    created_at=min(triggered_at, now),
                )
            )
        if level:
            _history(
                db,
                complaint,
                history[-1][1],
                ComplaintStatus.ESCALATED.value,
                None,
                f"SLA breached; escalated to level {level}",
                min(due_at + timedelta(hours=1), now),
            )

        generated += 1

    db.commit()
    print(f"  + Generated {generated} historical complaints")


def _make_road_image(path, defect: bool):
    width, height = 640, 420
    image = Image.new("RGB", (width, height), (120, 122, 120))
    draw = ImageDraw.Draw(image)
    # Asphalt texture
    rng = random.Random(7 if defect else 11)
    for _ in range(2200):
        x = rng.randint(0, width - 1)
        y = rng.randint(0, height - 1)
        shade = rng.randint(95, 145)
        draw.point((x, y), fill=(shade, shade, shade))
    # Lane markings
    for y in range(20, height, 70):
        draw.rectangle([width // 2 - 7, y, width // 2 + 7, y + 38], fill=(214, 210, 190))
    if defect:
        draw.ellipse([170, 170, 430, 330], fill=(45, 43, 40))
        draw.ellipse([195, 190, 405, 305], fill=(28, 27, 25))
        draw.arc([180, 175, 420, 330], 10, 170, fill=(70, 66, 60), width=6)
    else:
        draw.ellipse([170, 170, 430, 330], fill=(138, 140, 138))
        draw.rectangle([180, 250, 420, 255], fill=(110, 112, 110))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG")


def seed_attachments(db):
    complaint = (
        db.query(Complaint)
        .filter(Complaint.complaint_number == f"CIVIC-{YEAR}-0001")
        .first()
    )
    if not complaint:
        return
    if db.query(ComplaintAttachment).filter(ComplaintAttachment.complaint_id == complaint.id).first():
        return

    target_dir = uploads_root() / "complaints" / str(complaint.id)
    before_path = target_dir / "seed-pothole-before.png"
    _make_road_image(before_path, defect=True)
    db.add(
        ComplaintAttachment(
            complaint_id=complaint.id,
            file_path=f"/uploads/complaints/{complaint.id}/{before_path.name}",
            file_name="pothole-before.png",
            file_size=before_path.stat().st_size,
            mime_type="image/png",
        )
    )
    db.commit()
    print("  + Seeded evidence photo for CIVIC-%s-0001" % YEAR)


def seed_notifications(db, users):
    if db.query(Notification).count() > 0:
        return

    citizen = users["citizen@demo.civicai"]
    officer = users["officer@demo.civicai"]
    supervisor = users["supervisor@demo.civicai"]
    admin = users["admin@demo.civicai"]
    now = datetime.now(timezone.utc)

    complaints = (
        db.query(Complaint)
        .order_by(Complaint.created_at.desc())
        .limit(8)
        .all()
    )
    if not complaints:
        return

    def pick(index: int) -> Complaint:
        return complaints[index % len(complaints)]

    notifications = [
        (citizen, pick(0), "status_change", "Complaint status updated", f"{pick(0).complaint_number} is now {pick(0).status}.", False, 1),
        (citizen, pick(1), "status_change", "Complaint registered", f"{pick(1).complaint_number} was received and routed to the responsible department.", True, 5),
        (citizen, pick(2), "system", "Ward advisory", "Water supply maintenance is scheduled in your ward tomorrow from 10:00 to 14:00.", True, 26),
        (officer, pick(0), "assignment", "Complaint assigned to you", f"{pick(0).complaint_number} — {pick(0).title}", False, 2),
        (officer, pick(3), "escalation", "SLA breach warning", f"{pick(3).complaint_number} is approaching its resolution deadline.", False, 4),
        (supervisor, pick(3), "escalation", "Complaint escalated", f"{pick(3).complaint_number} breached its SLA and needs review.", False, 3),
        (admin, pick(3), "escalation", "Municipal SLA breach", f"{pick(3).complaint_number} was escalated to your desk.", False, 3),
        (admin, pick(4), "new_complaint", "New complaint filed", f"{pick(4).complaint_number} — {pick(4).title}", True, 30),
    ]
    for user, complaint, kind, title, message, is_read, hours_ago in notifications:
        db.add(
            Notification(
                user_id=user.id,
                complaint_id=complaint.id,
                notification_type=kind,
                title=title,
                message=message,
                is_read=is_read,
                created_at=now - timedelta(hours=hours_ago),
            )
        )
    db.commit()
    print("  + Seeded in-app notifications")


def seed_database(force: bool = False):
    if force:
        Base.metadata.drop_all(bind=engine)
        print("[*] Dropped existing tables (--force)")

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if db.query(User).count() > 0:
            print(
                "[SKIP] Database already contains users. "
                "Re-run with --force to wipe and reseed."
            )
            return
        print("[*] Seeding CivicAI demo municipality...")
        departments = seed_departments(db)
        categories = seed_categories(db, departments)
        users = seed_users(db, departments)
        seed_escalation_rules(db)
        seed_base_complaints(db, departments, categories, users)
        seed_generated_complaints(db, departments, categories, users)
        seed_attachments(db)
        seed_notifications(db, users)
        print("[OK] Demo data ready.")
        print(f"     Sign in with citizen@demo.civicai / {DEMO_PASSWORD}")
        print(f"     Staff demo: admin@demo.civicai / {DEMO_PASSWORD}")
    except Exception as exc:
        db.rollback()
        print(f"[ERROR] Seeding failed: {exc}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Seed the CivicAI demo municipality.")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Drop every table and rebuild the demo dataset from scratch.",
    )
    args = parser.parse_args()
    seed_database(force=args.force)
