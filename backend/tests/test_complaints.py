from backend.tests.conftest import auth_header_for_user


def test_create_complaint_success(client, seed_data):
    """Citizen submits complaint; verify number generation, SLA calculation, and initial status."""
    citizen_headers = auth_header_for_user(seed_data["citizen"])
    payload = {
        "department_id": seed_data["dept"].id,
        "category_id": seed_data["category"].id,
        "title": "Severe pothole near market entrance",
        "description": "Large deep pothole creating severe traffic blockage and two-wheeler accidents.",
        "ward": "Ward 12",
        "address": "Main Market Road, near Gate 1",
        "landmark": "Opposite SBI Branch",
        "latitude": 12.9716,
        "longitude": 77.6412,
    }

    response = client.post("/api/v1/complaints", json=payload, headers=citizen_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["complaint_number"].startswith("CIVIC-")
    assert data["status"] == "submitted"
    assert data["priority"] == "medium"
    assert data["escalation_level"] == 0
    assert data["due_at"] is not None


def test_create_complaint_invalid_department(client, seed_data):
    """Submitting complaint with non-existent department returns 400."""
    citizen_headers = auth_header_for_user(seed_data["citizen"])
    payload = {
        "department_id": 99999,
        "category_id": seed_data["category"].id,
        "title": "Invalid department test",
        "description": "Testing that invalid department ID is rejected by system.",
        "ward": "Ward 12",
        "address": "Test Road",
    }
    response = client.post("/api/v1/complaints", json=payload, headers=citizen_headers)
    assert response.status_code == 400
    assert "Department with ID" in response.json()["detail"]


def test_complaint_role_based_listing(client, seed_data):
    """Citizens only see their own complaints; Admin sees all."""
    c1_headers = auth_header_for_user(seed_data["citizen"])
    c2_headers = auth_header_for_user(seed_data["other_citizen"])
    admin_headers = auth_header_for_user(seed_data["admin"])

    # Citizen 1 creates complaint
    p1 = {
        "department_id": seed_data["dept"].id,
        "category_id": seed_data["category"].id,
        "title": "Citizen 1 Complaint",
        "description": "Description for complaint 1 by citizen 1.",
        "ward": "Ward 12",
        "address": "Address 1",
    }
    resp1 = client.post("/api/v1/complaints", json=p1, headers=c1_headers)
    assert resp1.status_code == 201

    # Citizen 2 creates complaint
    p2 = {
        "department_id": seed_data["dept"].id,
        "category_id": seed_data["category"].id,
        "title": "Citizen 2 Complaint",
        "description": "Description for complaint 2 by citizen 2.",
        "ward": "Ward 15",
        "address": "Address 2",
    }
    resp2 = client.post("/api/v1/complaints", json=p2, headers=c2_headers)
    assert resp2.status_code == 201

    # Citizen 1 lists: should only see 1 complaint
    list_c1 = client.get("/api/v1/complaints", headers=c1_headers).json()
    assert len(list_c1) == 1
    assert list_c1[0]["title"] == "Citizen 1 Complaint"

    # Citizen 2 lists: should only see 1 complaint
    list_c2 = client.get("/api/v1/complaints", headers=c2_headers).json()
    assert len(list_c2) == 1
    assert list_c2[0]["title"] == "Citizen 2 Complaint"

    # Admin lists: should see both complaints
    list_admin = client.get("/api/v1/complaints", headers=admin_headers).json()
    assert len(list_admin) >= 2


def test_complaint_access_control(client, seed_data):
    """Citizen cannot retrieve another citizen's complaint details."""
    c1_headers = auth_header_for_user(seed_data["citizen"])
    c2_headers = auth_header_for_user(seed_data["other_citizen"])

    # Citizen 1 creates complaint
    p1 = {
        "department_id": seed_data["dept"].id,
        "category_id": seed_data["category"].id,
        "title": "Private Citizen 1 Issue",
        "description": "Detailed description of citizen 1 problem.",
        "ward": "Ward 12",
        "address": "Address 1",
    }
    created = client.post("/api/v1/complaints", json=p1, headers=c1_headers).json()
    complaint_id = created["id"]

    # Citizen 1 can access
    r1 = client.get(f"/api/v1/complaints/{complaint_id}", headers=c1_headers)
    assert r1.status_code == 200

    # Citizen 2 cannot access (403 Forbidden)
    r2 = client.get(f"/api/v1/complaints/{complaint_id}", headers=c2_headers)
    assert r2.status_code == 403


def test_status_update_and_timeline(client, seed_data):
    """Officer updates complaint status; verify transition and timeline logging."""
    citizen_headers = auth_header_for_user(seed_data["citizen"])
    officer_headers = auth_header_for_user(seed_data["officer"])

    # Citizen creates complaint
    created = client.post(
        "/api/v1/complaints",
        json={
            "department_id": seed_data["dept"].id,
            "category_id": seed_data["category"].id,
            "title": "Test for status updates",
            "description": "Complaint description testing status transitions.",
            "ward": "Ward 12",
            "address": "Street 9",
        },
        headers=citizen_headers,
    ).json()
    complaint_id = created["id"]

    # Citizen attempts to update status -> 403 Forbidden
    unauth_update = client.put(
        f"/api/v1/complaints/{complaint_id}/status",
        json={"status": "in_progress", "comments": "Citizen trying to change status"},
        headers=citizen_headers,
    )
    assert unauth_update.status_code == 403

    # Officer updates to in_progress
    update_resp = client.put(
        f"/api/v1/complaints/{complaint_id}/status",
        json={"status": "in_progress", "comments": "Repair crew deployed"},
        headers=officer_headers,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["status"] == "in_progress"

    # Officer updates to resolved
    resolve_resp = client.put(
        f"/api/v1/complaints/{complaint_id}/status",
        json={"status": "resolved", "comments": "Pothole filled and sealed"},
        headers=officer_headers,
    )
    assert resolve_resp.status_code == 200
    assert resolve_resp.json()["status"] == "resolved"
    assert resolve_resp.json()["resolved_at"] is not None

    # Check timeline
    timeline_resp = client.get(f"/api/v1/complaints/{complaint_id}/timeline", headers=citizen_headers)
    assert timeline_resp.status_code == 200
    history = timeline_resp.json()
    assert len(history) == 3  # submitted -> in_progress -> resolved
    assert history[0]["new_status"] == "submitted"
    assert history[1]["new_status"] == "in_progress"
    assert history[2]["new_status"] == "resolved"
