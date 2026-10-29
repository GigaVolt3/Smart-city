from datetime import datetime, timedelta, timezone
from backend.core.database import SessionLocal, Base, engine
from backend.core.security import hash_password
from backend.models.department import Department
from backend.models.category import ComplaintCategory
from backend.models.user import User
from backend.models.complaint import Complaint
from backend.models.status_history import StatusHistory
from backend.models.enums import UserRole, ComplaintStatus, ComplaintPriority


def seed_database():
    """Seed fictional demo accounts, municipal departments, categories, and complaints."""
    # Ensure tables exist
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        print("[*] Checking and seeding CivicAI demo data...")

        # 1. Seed Municipal Departments
        departments_data = [
            {
                "name": "Roads & Infrastructure",
                "code": "ROADS",
                "description": "Maintenance of arterial roads, footpaths, bridges, and pothole patching",
                "contact_email": "roads@demo.civicai",
                "contact_phone": "+91-80-2222-1001",
            },
            {
                "name": "Solid Waste & Sanitation",
                "code": "SAN",
                "description": "Garbage collection, street sweeping, dump yards, and dead animal removal",
                "contact_email": "sanitation@demo.civicai",
                "contact_phone": "+91-80-2222-1002",
            },
            {
                "name": "Street Lighting & Electrical",
                "code": "ELEC",
                "description": "Streetlight maintenance, high-mast lamps, timers, and exposed electrical hazards",
                "contact_email": "electrical@demo.civicai",
                "contact_phone": "+91-80-2222-1003",
            },
            {
                "name": "Water Supply & Sewerage",
                "code": "WATER",
                "description": "Drinking water supply, pipeline bursts, leakages, and sewage blockages",
                "contact_email": "water@demo.civicai",
                "contact_phone": "+91-80-2222-1004",
            },
            {
                "name": "Storm Water Drains & Flood Control",
                "code": "DRAIN",
                "description": "Cleaning primary and secondary storm drains, open manholes, and flood mitigation",
                "contact_email": "drains@demo.civicai",
                "contact_phone": "+91-80-2222-1005",
            },
        ]

        depts = {}
        for dept_dict in departments_data:
            dept = db.query(Department).filter(Department.code == dept_dict["code"]).first()
            if not dept:
                dept = Department(**dept_dict)
                db.add(dept)
                db.flush()
                print(f"  + Added Department: {dept.name} ({dept.code})")
            depts[dept.code] = dept

        db.commit()

        # 2. Seed Complaint Categories
        categories_data = [
            # Roads
            {
                "department_id": depts["ROADS"].id,
                "name": "Pothole Repair",
                "code": "POTHOLE",
                "description": "Road surface potholes and craters causing traffic bottlenecks",
                "sla_hours": 48,
                "priority_default": ComplaintPriority.MEDIUM.value,
            },
            {
                "department_id": depts["ROADS"].id,
                "name": "Damaged Road Surface / Trench",
                "code": "DAMAGED_ROAD",
                "description": "Unpaved trenches or asphalt breakdown across roadway",
                "sla_hours": 72,
                "priority_default": ComplaintPriority.MEDIUM.value,
            },
            # Sanitation
            {
                "department_id": depts["SAN"].id,
                "name": "Garbage Pile / Overflowing Bin",
                "code": "GARBAGE_ACCUMULATION",
                "description": "Uncollected domestic garbage or overflowing community waste bins",
                "sla_hours": 24,
                "priority_default": ComplaintPriority.HIGH.value,
            },
            {
                "department_id": depts["SAN"].id,
                "name": "Dead Animal Disposal",
                "code": "DEAD_ANIMAL",
                "description": "Carcass requiring immediate safe sanitary disposal",
                "sla_hours": 8,
                "priority_default": ComplaintPriority.CRITICAL.value,
            },
            # Electrical
            {
                "department_id": depts["ELEC"].id,
                "name": "Streetlight Not Working",
                "code": "STREETLIGHT_BROKEN",
                "description": "Single or multiple streetlights malfunctioning or off during night",
                "sla_hours": 24,
                "priority_default": ComplaintPriority.MEDIUM.value,
            },
            {
                "department_id": depts["ELEC"].id,
                "name": "Exposed Wiring / Sparking Pole",
                "code": "EXPOSED_WIRING",
                "description": "Open live cables or electrical poles emitting sparks",
                "sla_hours": 4,
                "priority_default": ComplaintPriority.CRITICAL.value,
            },
            # Water
            {
                "department_id": depts["WATER"].id,
                "name": "Pipeline Water Leakage",
                "code": "WATER_LEAKAGE",
                "description": "Main potable water line rupture or valve leakage on public street",
                "sla_hours": 24,
                "priority_default": ComplaintPriority.HIGH.value,
            },
            {
                "department_id": depts["WATER"].id,
                "name": "Contaminated Water Supply",
                "code": "CONTAMINATED_WATER",
                "description": "Discolored, turbid, or foul-smelling tap water delivery",
                "sla_hours": 12,
                "priority_default": ComplaintPriority.CRITICAL.value,
            },
            # Drains
            {
                "department_id": depts["DRAIN"].id,
                "name": "Blocked Storm Drain",
                "code": "DRAIN_BLOCKED",
                "description": "Clogged roadside drainage causing water stagnation",
                "sla_hours": 48,
                "priority_default": ComplaintPriority.HIGH.value,
            },
            {
                "department_id": depts["DRAIN"].id,
                "name": "Open / Missing Manhole Cover",
                "code": "OPEN_MANHOLE",
                "description": "Severe public hazard from missing or collapsed storm cover",
                "sla_hours": 4,
                "priority_default": ComplaintPriority.CRITICAL.value,
            },
        ]

        cats = {}
        for cat_dict in categories_data:
            cat = db.query(ComplaintCategory).filter(ComplaintCategory.code == cat_dict["code"]).first()
            if not cat:
                cat = ComplaintCategory(**cat_dict)
                db.add(cat)
                db.flush()
                print(f"  + Added Category: {cat.name} ({cat.code})")
            cats[cat.code] = cat

        db.commit()

        # 3. Seed Demo Users
        password_hash = hash_password("DemoPass1!")
        demo_users = [
            {
                "email": "citizen@demo.civicai",
                "full_name": "Ramesh Kumar",
                "phone_number": "+91-98765-43210",
                "role": UserRole.CITIZEN.value,
                "ward": "Ward 12 (Indiranagar)",
                "department_id": None,
                "hashed_password": password_hash,
            },
            {
                "email": "officer@demo.civicai",
                "full_name": "Priya Sharma (AE)",
                "phone_number": "+91-98765-43211",
                "role": UserRole.OFFICER.value,
                "ward": "Ward 12 (Indiranagar)",
                "department_id": depts["ROADS"].id,
                "hashed_password": password_hash,
            },
            {
                "email": "supervisor@demo.civicai",
                "full_name": "Dr. Anand Rao (EE)",
                "phone_number": "+91-98765-43212",
                "role": UserRole.SUPERVISOR.value,
                "ward": "East Zone HQ",
                "department_id": depts["ROADS"].id,
                "hashed_password": password_hash,
            },
            {
                "email": "admin@demo.civicai",
                "full_name": "Chief Municipal Administrator",
                "phone_number": "+91-98765-43213",
                "role": UserRole.ADMIN.value,
                "ward": "Municipal Corporation Central",
                "department_id": None,
                "hashed_password": password_hash,
            },
        ]

        users = {}
        for user_dict in demo_users:
            user = db.query(User).filter(User.email == user_dict["email"]).first()
            if not user:
                user = User(**user_dict)
                db.add(user)
                db.flush()
                print(f"  + Added User: {user.full_name} ({user.email}) -> Role: {user.role}")
            users[user.role] = user

        db.commit()

        # 4. Seed Realistic Sample Complaints
        now = datetime.now(timezone.utc)
        sample_complaints = [
            {
                "complaint_number": "CIVIC-2026-0001",
                "citizen_id": users[UserRole.CITIZEN.value].id,
                "assigned_officer_id": users[UserRole.OFFICER.value].id,
                "department_id": depts["ROADS"].id,
                "category_id": cats["POTHOLE"].id,
                "title": "Large crater pothole on 100ft Road junction",
                "description": "Deep pothole measuring approximately 2 feet wide right near the metro pillar junction. Vehicles are braking abruptly leading to minor collisions.",
                "ward": "Ward 12 (Indiranagar)",
                "address": "Opposite Metro Pillar 142, 100 Feet Rd, HAL 2nd Stage",
                "landmark": "Near Coffee Day Signal",
                "latitude": 12.9716,
                "longitude": 77.6412,
                "status": ComplaintStatus.IN_PROGRESS.value,
                "priority": ComplaintPriority.HIGH.value,
                "escalation_level": 0,
                "due_at": now + timedelta(hours=36),
                "created_at": now - timedelta(hours=12),
                "updated_at": now - timedelta(hours=2),
                "history": [
                    {
                        "prev": None,
                        "new": ComplaintStatus.SUBMITTED.value,
                        "by": users[UserRole.CITIZEN.value].id,
                        "comments": "Complaint submitted with location coordinates",
                        "time": now - timedelta(hours=12),
                    },
                    {
                        "prev": ComplaintStatus.SUBMITTED.value,
                        "new": ComplaintStatus.ASSIGNED.value,
                        "by": users[UserRole.SUPERVISOR.value].id,
                        "comments": "Assigned to Ward Assistant Engineer Priya Sharma",
                        "time": now - timedelta(hours=8),
                    },
                    {
                        "prev": ComplaintStatus.ASSIGNED.value,
                        "new": ComplaintStatus.IN_PROGRESS.value,
                        "by": users[UserRole.OFFICER.value].id,
                        "comments": "Inspection complete; asphalt mix dispatched for hot-pour filling",
                        "time": now - timedelta(hours=2),
                    },
                ],
            },
            {
                "complaint_number": "CIVIC-2026-0002",
                "citizen_id": users[UserRole.CITIZEN.value].id,
                "assigned_officer_id": None,
                "department_id": depts["SAN"].id,
                "category_id": cats["GARBAGE_ACCUMULATION"].id,
                "title": "Overflowing waste dumpster attracting stray dogs",
                "description": "The community waste bin has not been cleared for 3 consecutive days. Refuse has spilled onto the roadway blocking the walking path.",
                "ward": "Ward 12 (Indiranagar)",
                "address": "7th Cross, 4th Main, Defence Colony",
                "landmark": "Adjacent to Public Park gate 2",
                "latitude": 12.9754,
                "longitude": 77.6450,
                "status": ComplaintStatus.SUBMITTED.value,
                "priority": ComplaintPriority.HIGH.value,
                "escalation_level": 0,
                "due_at": now + timedelta(hours=18),
                "created_at": now - timedelta(hours=6),
                "updated_at": now - timedelta(hours=6),
                "history": [
                    {
                        "prev": None,
                        "new": ComplaintStatus.SUBMITTED.value,
                        "by": users[UserRole.CITIZEN.value].id,
                        "comments": "Citizen reported garbage accumulation",
                        "time": now - timedelta(hours=6),
                    },
                ],
            },
            {
                "complaint_number": "CIVIC-2026-0003",
                "citizen_id": users[UserRole.CITIZEN.value].id,
                "assigned_officer_id": None,
                "department_id": depts["DRAIN"].id,
                "category_id": cats["OPEN_MANHOLE"].id,
                "title": "Broken cement cover on footpath drain",
                "description": "Missing chamber slab creating open 5-foot pit on walking path right next to high school bus stand. High risk of pedestrian injury.",
                "ward": "Ward 15 (Domlur)",
                "address": "Airport Road service lane, Domlur",
                "landmark": "Near National Public School bus stop",
                "latitude": 12.9609,
                "longitude": 77.6387,
                "status": ComplaintStatus.SUBMITTED.value,
                "priority": ComplaintPriority.CRITICAL.value,
                "escalation_level": 0,
                "due_at": now + timedelta(hours=2),
                "created_at": now - timedelta(hours=2),
                "updated_at": now - timedelta(hours=2),
                "history": [
                    {
                        "prev": None,
                        "new": ComplaintStatus.SUBMITTED.value,
                        "by": users[UserRole.CITIZEN.value].id,
                        "comments": "Critical open manhole alert submitted",
                        "time": now - timedelta(hours=2),
                    },
                ],
            },
            {
                "complaint_number": "CIVIC-2026-0004",
                "citizen_id": users[UserRole.CITIZEN.value].id,
                "assigned_officer_id": users[UserRole.OFFICER.value].id,
                "department_id": depts["ELEC"].id,
                "category_id": cats["STREETLIGHT_BROKEN"].id,
                "title": "Series of 4 streetlights dark for 2 nights",
                "description": "Entire stretch of residential lane completely pitch dark after 7 PM.",
                "ward": "Ward 12 (Indiranagar)",
                "address": "12th B Main, HAL 2nd Stage",
                "landmark": "Behind BDA Complex",
                "latitude": 12.9698,
                "longitude": 77.6391,
                "status": ComplaintStatus.RESOLVED.value,
                "priority": ComplaintPriority.MEDIUM.value,
                "escalation_level": 0,
                "due_at": now - timedelta(hours=10),
                "resolved_at": now - timedelta(hours=4),
                "created_at": now - timedelta(hours=28),
                "updated_at": now - timedelta(hours=4),
                "history": [
                    {
                        "prev": None,
                        "new": ComplaintStatus.SUBMITTED.value,
                        "by": users[UserRole.CITIZEN.value].id,
                        "comments": "Citizen grievance logged",
                        "time": now - timedelta(hours=28),
                    },
                    {
                        "prev": ComplaintStatus.SUBMITTED.value,
                        "new": ComplaintStatus.IN_PROGRESS.value,
                        "by": users[UserRole.OFFICER.value].id,
                        "comments": "Linesman deployed to inspect feeder pillar fuse",
                        "time": now - timedelta(hours=14),
                    },
                    {
                        "prev": ComplaintStatus.IN_PROGRESS.value,
                        "new": ComplaintStatus.RESOLVED.value,
                        "by": users[UserRole.OFFICER.value].id,
                        "comments": "Blown phase fuse replaced and LED driver checked; all 4 lights operational",
                        "time": now - timedelta(hours=4),
                    },
                ],
            },
        ]

        for comp_data in sample_complaints:
            existing = db.query(Complaint).filter(Complaint.complaint_number == comp_data["complaint_number"]).first()
            if not existing:
                history_list = comp_data.pop("history")
                complaint = Complaint(**comp_data)
                db.add(complaint)
                db.flush()

                for h in history_list:
                    hist = StatusHistory(
                        complaint_id=complaint.id,
                        previous_status=h["prev"],
                        new_status=h["new"],
                        changed_by_id=h["by"],
                        comments=h["comments"],
                        created_at=h["time"],
                    )
                    db.add(hist)

                print(f"  + Added Complaint: {complaint.complaint_number} - {complaint.title} ({complaint.status})")

        db.commit()
        print("[OK] CivicAI database seeding completed successfully!")

    except Exception as e:
        db.rollback()
        print(f"[ERROR] Error during database seeding: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
