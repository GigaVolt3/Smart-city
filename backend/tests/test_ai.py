import io
from datetime import datetime, timezone
import pytest
from PIL import Image, ImageDraw

from backend.ai.classifier import CivicClassifier
from backend.ai.duplicate_detector import DuplicateDetector, haversine_distance
from backend.ai.priority_scorer import CivicPriorityScorer
from backend.ai.hotspot_detector import CivicHotspotDetector
from backend.ai.image_comparator import CivicImageComparator
from backend.models.complaint import Complaint
from backend.models.department import Department
from backend.models.category import ComplaintCategory
from backend.tests.conftest import auth_header_for_user


# Helper to generate test images in-memory
def create_test_image(pattern: str = "road_pothole") -> bytes:
    img = Image.new("RGB", (200, 200), color=(128, 128, 128))
    draw = ImageDraw.Draw(img)

    if pattern == "road_pothole":
        # Grey road with dark pothole crater in the center
        draw.ellipse([70, 70, 130, 130], fill=(30, 30, 30))
        draw.line([0, 100, 200, 100], fill=(255, 255, 255), width=3)  # Road stripe
    elif pattern == "road_repaired":
        # Same road, pothole filled with fresh black asphalt and road stripe
        draw.ellipse([70, 70, 130, 130], fill=(90, 90, 90))
        draw.line([0, 100, 200, 100], fill=(255, 255, 255), width=3)
    elif pattern == "blank":
        # Solid uniform black image
        img = Image.new("RGB", (200, 200), color=(0, 0, 0))
    elif pattern == "park":
        # Completely different scene: bright green and sky blue
        img = Image.new("RGB", (200, 200), color=(34, 139, 34))
        draw = ImageDraw.Draw(img)
        draw.rectangle([0, 0, 200, 80], fill=(135, 206, 235))

    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


# -------------------------------------------------------------
# 1. Complaint Classification Tests
# -------------------------------------------------------------
def test_classifier_unit(db_session, seed_data):
    classifier = CivicClassifier()
    # Pothole query
    res = classifier.classify(
        title="Deep dangerous crater on main road",
        description="There is a large pothole breaking vehicle suspensions and slowing down traffic.",
        db=db_session,
    )
    assert res["category_code"] == "POTHOLE"
    assert res["confidence"] > 0.3
    assert "pothole" in res["matched_keywords"] or "crater" in res["matched_keywords"]


def test_classifier_api(client, seed_data):
    headers = auth_header_for_user(seed_data["citizen"])
    response = client.post(
        "/api/v1/ai/classify",
        headers=headers,
        json={
            "title": "Severe pothole and crater",
            "description": "Asphalt is broken and large potholes have formed near the crossroad.",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["category_code"] == "POTHOLE"
    assert data["confidence"] > 0.0
    assert len(data["candidates"]) > 0


# -------------------------------------------------------------
# 2. Duplicate Detection Tests
# -------------------------------------------------------------
def test_haversine_distance():
    # MG Road to Brigade Road, Bangalore (~500m)
    dist = haversine_distance(12.9716, 77.5946, 12.9750, 77.5990)
    assert 400 < dist < 700

    # Same location distance is 0
    assert haversine_distance(12.9716, 77.5946, 12.9716, 77.5946) == 0.0


def test_duplicate_detector_unit(db_session, seed_data):
    now = datetime.now(timezone.utc)
    # Seed an existing complaint
    c1 = Complaint(
        complaint_number="CIVIC-2026-TEST-01",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Huge pothole near metro pillar 120",
        description="Deep pothole causing serious bike skids at pillar 120.",
        ward="Ward 12",
        address="100ft Road, Indiranagar",
        latitude=12.9716,
        longitude=77.5946,
        status="submitted",
        priority="high",
        due_at=now,
        created_at=now,
        updated_at=now,
    )
    db_session.add(c1)
    db_session.commit()

    detector = DuplicateDetector(default_radius_meters=150.0)

    # Similar text + 20 meters away
    dup_res = detector.find_duplicates(
        title="Dangerous deep pothole near metro pillar 120",
        description="Bike riders are skidding into huge pothole next to pillar 120.",
        latitude=12.9717,
        longitude=77.5947,
        db=db_session,
        category_id=seed_data["category"].id,
    )
    assert dup_res["is_duplicate"] is True
    assert dup_res["confidence"] >= 0.65
    assert dup_res["primary_complaint_id"] == c1.id
    assert dup_res["matches"][0]["distance_meters"] < 30.0

    # Completely different location & different topic
    non_dup = detector.find_duplicates(
        title="Streetlight flickering",
        description="Lamp post bulb is dark at night.",
        latitude=13.0500,
        longitude=77.6200,
        db=db_session,
    )
    assert non_dup["is_duplicate"] is False


def test_duplicate_detector_api(client, seed_data, db_session):
    now = datetime.now(timezone.utc)
    c1 = Complaint(
        complaint_number="CIVIC-2026-TEST-02",
        citizen_id=seed_data["citizen"].id,
        department_id=seed_data["dept"].id,
        category_id=seed_data["category"].id,
        title="Water pipeline leaking heavily",
        description="Gushing water on road surface wasting drinking water.",
        ward="Ward 12",
        address="Near Main Market",
        latitude=12.9500,
        longitude=77.6000,
        status="submitted",
        priority="high",
        due_at=now,
        created_at=now,
        updated_at=now,
    )
    db_session.add(c1)
    db_session.commit()

    headers = auth_header_for_user(seed_data["citizen"])
    res = client.post(
        "/api/v1/ai/check-duplicates",
        headers=headers,
        json={
            "title": "Water pipe leak on road",
            "description": "Drinking water is leaking heavily from burst pipe.",
            "latitude": 12.9501,
            "longitude": 77.6001,
            "category_id": seed_data["category"].id,
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["is_duplicate"] is True
    assert len(data["matches"]) >= 1


# -------------------------------------------------------------
# 3. AI Priority Scoring Tests
# -------------------------------------------------------------
def test_priority_scorer_critical_hazard():
    scorer = CivicPriorityScorer()
    res = scorer.score_complaint(
        title="Live sparking electrical wire on road",
        description="Open live wire sparking next to children school bus stop. Electrocution risk!",
        ward="Ward 10",
        landmark="Opposite St Joseph School",
        duplicate_count=3,
    )
    assert res["priority_level"] == "critical"
    assert res["priority_score"] >= 75
    assert res["recommended_sla_hours"] <= 6
    assert any("Live" in f or "electrical" in f for f in res["factors"])
    assert any("School" in f or "child" in f for f in res["factors"])


def test_priority_scorer_routine_low():
    scorer = CivicPriorityScorer()
    res = scorer.score_complaint(
        title="Minor paint peel on divider",
        description="The white paint on the road divider is slightly faded and needs repainting.",
        ward="Ward 5",
        duplicate_count=0,
    )
    assert res["priority_level"] in ["low", "medium"]
    assert res["priority_score"] < 50


def test_priority_scorer_api(client, seed_data):
    headers = auth_header_for_user(seed_data["citizen"])
    res = client.post(
        "/api/v1/ai/score-priority",
        headers=headers,
        json={
            "title": "Open manhole in front of hospital",
            "description": "Manhole cover is completely missing right outside City Care Hospital emergency entrance.",
            "ward": "Ward 12",
            "landmark": "City Care Hospital",
            "duplicate_count": 2,
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["priority_level"] in ["critical", "high"]
    assert data["priority_score"] >= 50
    assert len(data["factors"]) > 0


# -------------------------------------------------------------
# 4. Hotspot Detection Tests
# -------------------------------------------------------------
def test_hotspot_detector_unit(db_session, seed_data):
    now = datetime.now(timezone.utc)
    # Seed 3 complaints closely clustered at (12.9200, 77.5800) within 50 meters
    for i in range(3):
        c = Complaint(
            complaint_number=f"CIVIC-2026-HOT-{i}",
            citizen_id=seed_data["citizen"].id,
            department_id=seed_data["dept"].id,
            category_id=seed_data["category"].id,
            title=f"Recurring road issue {i}",
            description="Persistent recurring damage on this intersection.",
            ward="Ward 12",
            address="Jayanagar 4th Block",
            latitude=12.9200 + (i * 0.0002),
            longitude=77.5800 + (i * 0.0002),
            status="submitted",
            priority="medium",
            due_at=now,
            created_at=now,
            updated_at=now,
        )
        db_session.add(c)
    db_session.commit()

    detector = CivicHotspotDetector()
    res = detector.detect_hotspots(
        db=db_session,
        cluster_radius_meters=200.0,
        min_complaints=2,
    )
    assert res["total_hotspots"] >= 1
    assert len(res["hotspots"]) >= 1
    cluster = res["hotspots"][0]
    assert cluster["total_complaints"] >= 3
    assert cluster["recurrence_score"] > 0
    assert "FeatureCollection" == res["geojson"]["type"]


def test_hotspot_detector_api(client, seed_data, db_session):
    headers = auth_header_for_user(seed_data["supervisor"])
    res = client.get("/api/v1/ai/hotspots?min_complaints=2", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert "total_hotspots" in data
    assert "geojson" in data
    assert "summary" in data


# -------------------------------------------------------------
# 5. Before-and-After Image Comparison Tests
# -------------------------------------------------------------
def test_image_comparator_fraud_identical():
    comparator = CivicImageComparator()
    img_bytes = create_test_image("road_pothole")

    # Identical image re-uploaded
    res = comparator.compare(img_bytes, img_bytes)
    assert res["is_verified"] is False
    assert res["verification_status"] == "FRAUD_IDENTICAL_IMAGE"
    assert res["resolution_score"] == 0.0


def test_image_comparator_fraud_dummy():
    comparator = CivicImageComparator()
    before = create_test_image("road_pothole")
    blank = create_test_image("blank")

    res = comparator.compare(before, blank)
    assert res["is_verified"] is False
    assert res["verification_status"] == "FRAUD_DUMMY_IMAGE"


def test_image_comparator_verified_resolution():
    comparator = CivicImageComparator()
    before = create_test_image("road_pothole")
    after = create_test_image("road_repaired")

    res = comparator.compare(before, after)
    assert res["is_verified"] is True
    assert res["verification_status"] in ["VERIFIED_RESOLVED", "LIKELY_RESOLVED"]
    assert res["resolution_score"] >= 50.0
    assert res["metrics"]["visual_change_percentage"] > 0.0


def test_image_comparator_api(client, seed_data):
    headers = auth_header_for_user(seed_data["officer"])
    before_bytes = create_test_image("road_pothole")
    after_bytes = create_test_image("road_repaired")

    res = client.post(
        "/api/v1/ai/compare-images",
        headers=headers,
        files={
            "before_image": ("before.jpg", before_bytes, "image/jpeg"),
            "after_image": ("after.jpg", after_bytes, "image/jpeg"),
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["is_verified"] is True
    assert "metrics" in data


# -------------------------------------------------------------
# 6. Integration: Complaint Creation with AI Dynamic Priority
# -------------------------------------------------------------
def test_complaint_creation_dynamic_ai_priority(client, seed_data):
    headers = auth_header_for_user(seed_data["citizen"])
    res = client.post(
        "/api/v1/complaints",
        headers=headers,
        json={
            "department_id": seed_data["dept"].id,
            "category_id": seed_data["category"].id,
            "title": "Exposed live wire sparking on road",
            "description": "Danger: exposed sparking cable near busy intersection. Electric shock risk!",
            "ward": "Ward 12",
            "address": "Opposite Main Metro Station",
            # Note: priority is omitted to trigger dynamic AI priority scoring!
        },
    )
    assert res.status_code == 201
    data = res.json()
    # Scorer should elevate this to critical or high because of live wire hazard!
    assert data["priority"] in ["critical", "high"]
