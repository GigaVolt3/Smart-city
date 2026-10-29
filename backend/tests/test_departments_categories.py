from backend.tests.conftest import auth_header_for_user


def test_list_departments(client, seed_data):
    """Listing departments returns available departments."""
    response = client.get("/api/v1/departments")
    assert response.status_code == 200
    depts = response.json()
    assert len(depts) >= 1
    assert depts[0]["code"] == "ROADS"


def test_create_department_authorization(client, seed_data):
    """Only Admin can create department; Citizen is rejected with 403."""
    admin_headers = auth_header_for_user(seed_data["admin"])
    citizen_headers = auth_header_for_user(seed_data["citizen"])

    dept_payload = {
        "name": "Health & Epidemics",
        "code": "HEALTH",
        "description": "Public health services",
    }

    # Citizen rejected
    r_cit = client.post("/api/v1/departments", json=dept_payload, headers=citizen_headers)
    assert r_cit.status_code == 403

    # Admin accepted
    r_adm = client.post("/api/v1/departments", json=dept_payload, headers=admin_headers)
    assert r_adm.status_code == 201
    assert r_adm.json()["code"] == "HEALTH"


def test_create_category_authorization(client, seed_data):
    """Only Admin can create category; Officer is rejected with 403."""
    admin_headers = auth_header_for_user(seed_data["admin"])
    officer_headers = auth_header_for_user(seed_data["officer"])

    cat_payload = {
        "department_id": seed_data["dept"].id,
        "name": "Footpath Obstruction",
        "code": "FOOTPATH_BLOCKED",
        "description": "Footpath encroached by vendors or debris",
        "sla_hours": 36,
        "priority_default": "medium",
        "is_active": True,
    }

    # Officer rejected
    r_off = client.post("/api/v1/categories", json=cat_payload, headers=officer_headers)
    assert r_off.status_code == 403

    # Admin accepted
    r_adm = client.post("/api/v1/categories", json=cat_payload, headers=admin_headers)
    assert r_adm.status_code == 201
    assert r_adm.json()["code"] == "FOOTPATH_BLOCKED"
