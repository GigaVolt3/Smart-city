import math
from collections import Counter
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Any
import numpy as np
from sqlalchemy.orm import Session
from sklearn.cluster import DBSCAN

from backend.models.complaint import Complaint
from backend.models.category import ComplaintCategory
from backend.models.department import Department
from backend.models.enums import ComplaintStatus
from backend.ai.duplicate_detector import haversine_distance


class CivicHotspotDetector:
    """
    AI-powered recurring grievance hotspot detection engine.
    Uses DBSCAN spatial clustering on geographic coordinates to uncover chronic
    infrastructure failure hotspots, repetitive dumping sites, and recurring civic issues.
    """

    def detect_hotspots(
        self,
        db: Session,
        department_id: Optional[int] = None,
        category_id: Optional[int] = None,
        ward: Optional[str] = None,
        days_back: int = 90,
        cluster_radius_meters: float = 200.0,
        min_complaints: int = 2,
    ) -> Dict[str, Any]:
        """
        Executes spatial-temporal clustering over civic grievances.
        Returns detailed hotspot clusters, summary analytics, and standard GeoJSON output.
        """
        since_date = datetime.now(timezone.utc) - timedelta(days=days_back)
        query = db.query(Complaint).filter(
            Complaint.created_at >= since_date,
            Complaint.latitude.isnot(None),
            Complaint.longitude.isnot(None),
        )

        if department_id:
            query = query.filter(Complaint.department_id == department_id)
        if category_id:
            query = query.filter(Complaint.category_id == category_id)
        if ward:
            query = query.filter(Complaint.ward.ilike(f"%{ward}%"))

        complaints: List[Complaint] = query.all()

        if len(complaints) < min_complaints:
            return {
                "total_complaints_analyzed": len(complaints),
                "total_hotspots": 0,
                "hotspots": [],
                "geojson": {"type": "FeatureCollection", "features": []},
                "summary": {
                    "most_critical_ward": None,
                    "top_recurring_category": None,
                    "avg_cluster_size": 0.0,
                },
            }

        # Prepare coordinate arrays in radians for Haversine DBSCAN
        coords_deg = np.array([[c.latitude, c.longitude] for c in complaints])
        coords_rad = np.radians(coords_deg)

        # Earth radius in meters
        r_earth = 6371000.0
        eps_rad = cluster_radius_meters / r_earth

        dbscan = DBSCAN(eps=eps_rad, min_samples=min_complaints, metric="haversine")
        labels = dbscan.fit_predict(coords_rad)

        unique_labels = set(labels)
        hotspot_clusters = []

        # Category and Department caches
        category_cache = {c.id: c for c in db.query(ComplaintCategory).all()}
        dept_cache = {d.id: d for d in db.query(Department).all()}

        for cluster_id in unique_labels:
            if cluster_id == -1:
                # -1 denotes noise (unclustered isolated complaints)
                continue

            cluster_indices = [idx for idx, lbl in enumerate(labels) if lbl == cluster_id]
            cluster_complaints = [complaints[i] for i in cluster_indices]

            # 1. Centroid calculation
            cluster_lats = [c.latitude for c in cluster_complaints]
            cluster_lons = [c.longitude for c in cluster_complaints]
            centroid_lat = float(np.mean(cluster_lats))
            centroid_lon = float(np.mean(cluster_lons))

            # 2. Maximum spread radius in meters from centroid
            max_dist = 0.0
            for c in cluster_complaints:
                d = haversine_distance(centroid_lat, centroid_lon, c.latitude, c.longitude)
                if d > max_dist:
                    max_dist = d
            radius_meters = max(20.0, round(max_dist, 1))

            # 3. Status breakdown
            open_count = sum(
                1 for c in cluster_complaints if c.status not in [ComplaintStatus.RESOLVED.value, ComplaintStatus.REJECTED.value]
            )
            resolved_count = sum(
                1 for c in cluster_complaints if c.status == ComplaintStatus.RESOLVED.value
            )
            total_count = len(cluster_complaints)
            unresolved_rate = round(open_count / total_count, 2)

            # 4. Predominant category & department
            cat_counts = Counter(c.category_id for c in cluster_complaints)
            top_cat_id, top_cat_freq = cat_counts.most_common(1)[0]
            top_cat = category_cache.get(top_cat_id)

            dept_counts = Counter(c.department_id for c in cluster_complaints)
            top_dept_id, _ = dept_counts.most_common(1)[0]
            top_dept = dept_cache.get(top_dept_id)

            # 5. Affected Wards
            wards = sorted(list(set(c.ward for c in cluster_complaints if c.ward)))

            # 6. Temporal Recurrence
            created_times = sorted([c.created_at for c in cluster_complaints])
            time_span_days = max(1.0, (created_times[-1] - created_times[0]).total_seconds() / 86400.0)
            avg_recurrence_days = round(time_span_days / max(1, total_count - 1), 1)

            # 7. Chronic Recurrence Score (0-100)
            # High density + high unresolved rate + high recurrence frequency = high severity
            density_pts = min(40, total_count * 8)
            backlog_pts = unresolved_rate * 35
            recurrence_frequency_pts = 25 if avg_recurrence_days <= 7 else (15 if avg_recurrence_days <= 14 else 5)
            recurrence_score = min(100, int(density_pts + backlog_pts + recurrence_frequency_pts))

            if recurrence_score >= 75:
                severity_tier = "CHRONIC_CRITICAL"
            elif recurrence_score >= 50:
                severity_tier = "HIGH_RECURRENCE"
            elif recurrence_score >= 25:
                severity_tier = "MODERATE_HOTSPOT"
            else:
                severity_tier = "EMERGING"

            sample_complaints = [
                {
                    "id": c.id,
                    "complaint_number": c.complaint_number,
                    "title": c.title,
                    "status": c.status,
                    "created_at": c.created_at.isoformat(),
                }
                for c in sorted(cluster_complaints, key=lambda x: x.created_at, reverse=True)[:5]
            ]

            hotspot_clusters.append({
                "hotspot_id": f"HOTSPOT-{cluster_id + 1:03d}",
                "centroid": {"latitude": round(centroid_lat, 6), "longitude": round(centroid_lon, 6)},
                "radius_meters": radius_meters,
                "total_complaints": total_count,
                "open_complaints": open_count,
                "resolved_complaints": resolved_count,
                "unresolved_rate": unresolved_rate,
                "recurrence_score": recurrence_score,
                "severity_tier": severity_tier,
                "predominant_category": {
                    "id": top_cat_id,
                    "name": top_cat.name if top_cat else "Unknown",
                    "code": top_cat.code if top_cat else "UNKNOWN",
                },
                "predominant_department": {
                    "id": top_dept_id,
                    "name": top_dept.name if top_dept else "Unknown",
                    "code": top_dept.code if top_dept else "UNKNOWN",
                },
                "affected_wards": wards,
                "first_reported_at": created_times[0].isoformat(),
                "last_reported_at": created_times[-1].isoformat(),
                "avg_recurrence_interval_days": avg_recurrence_days,
                "sample_complaints": sample_complaints,
            })

        # Sort clusters by recurrence score descending
        hotspot_clusters.sort(key=lambda h: h["recurrence_score"], reverse=True)

        # Build GeoJSON
        geojson_features = []
        for h in hotspot_clusters:
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [h["centroid"]["longitude"], h["centroid"]["latitude"]],
                },
                "properties": {
                    "hotspot_id": h["hotspot_id"],
                    "radius_meters": h["radius_meters"],
                    "total_complaints": h["total_complaints"],
                    "open_complaints": h["open_complaints"],
                    "recurrence_score": h["recurrence_score"],
                    "severity_tier": h["severity_tier"],
                    "predominant_category": h["predominant_category"]["name"],
                    "predominant_department": h["predominant_department"]["name"],
                    "wards": ", ".join(h["affected_wards"]),
                },
            }
            geojson_features.append(feature)

        geojson = {"type": "FeatureCollection", "features": geojson_features}

        # Summary
        most_critical_ward = None
        top_recurring_category = None
        if hotspot_clusters:
            ward_counts = Counter(w for h in hotspot_clusters for w in h["affected_wards"])
            if ward_counts:
                most_critical_ward = ward_counts.most_common(1)[0][0]
            cat_counts = Counter(h["predominant_category"]["name"] for h in hotspot_clusters)
            if cat_counts:
                top_recurring_category = cat_counts.most_common(1)[0][0]

        return {
            "total_complaints_analyzed": len(complaints),
            "total_hotspots": len(hotspot_clusters),
            "hotspots": hotspot_clusters,
            "geojson": geojson,
            "summary": {
                "most_critical_ward": most_critical_ward,
                "top_recurring_category": top_recurring_category,
                "avg_cluster_size": round(
                    float(np.mean([h["total_complaints"] for h in hotspot_clusters])), 1
                ) if hotspot_clusters else 0.0,
            },
        }
