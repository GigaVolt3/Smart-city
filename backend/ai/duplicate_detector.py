import math
import re
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Any
from sqlalchemy.orm import Session
from sqlalchemy import or_
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from backend.models.complaint import Complaint
from backend.models.enums import ComplaintStatus


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Computes great-circle distance between two GPS coordinates in meters.
    Formula: d = 2R * arcsin(sqrt(sin^2(dlat/2) + cos(lat1)*cos(lat2)*sin^2(dlon/2)))
    """
    r_earth = 6371000.0  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    # Clamp 'a' to avoid float inaccuracies beyond 1.0
    a = min(1.0, max(0.0, a))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r_earth * c


class DuplicateDetector:
    """
    AI-powered duplicate grievance detection engine.
    Fuses spatial GPS proximity (Haversine distance) with semantic text similarity
    and municipal category alignment to accurately detect duplicate grievances.
    """

    def __init__(self, default_radius_meters: float = 150.0, default_threshold: float = 0.65):
        self.default_radius_meters = default_radius_meters
        self.default_threshold = default_threshold
        self._vectorizer = TfidfVectorizer(
            ngram_range=(1, 2),
            stop_words="english",
            lowercase=True,
            token_pattern=r"(?u)\b\w+\b",
        )

    def _clean_text(self, text: str) -> str:
        text = text.lower()
        text = re.sub(r"[^\w\s]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    def _jaccard_similarity(self, tokens1: set, tokens2: set) -> float:
        if not tokens1 or not tokens2:
            return 0.0
        intersection = len(tokens1.intersection(tokens2))
        union = len(tokens1.union(tokens2))
        return float(intersection) / float(union) if union > 0 else 0.0

    def find_duplicates(
        self,
        title: str,
        description: str,
        latitude: Optional[float],
        longitude: Optional[float],
        db: Session,
        category_id: Optional[int] = None,
        department_id: Optional[int] = None,
        radius_meters: Optional[float] = None,
        similarity_threshold: Optional[float] = None,
        exclude_complaint_id: Optional[int] = None,
        active_only: bool = True,
        days_lookback: int = 30,
    ) -> Dict[str, Any]:
        """
        Scans database for duplicate or highly similar grievances within spatial & semantic thresholds.
        """
        radius = radius_meters or self.default_radius_meters
        threshold = similarity_threshold or self.default_threshold

        query_text = f"{title} {description}".strip()
        cleaned_query = self._clean_text(query_text)
        query_tokens = set(cleaned_query.split())

        # Base DB query
        since_date = datetime.now(timezone.utc) - timedelta(days=days_lookback)
        complaints_query = db.query(Complaint).filter(Complaint.created_at >= since_date)

        if exclude_complaint_id:
            complaints_query = complaints_query.filter(Complaint.id != exclude_complaint_id)

        if active_only:
            # Focus on currently active or non-rejected complaints
            complaints_query = complaints_query.filter(
                Complaint.status.in_([
                    ComplaintStatus.SUBMITTED.value,
                    ComplaintStatus.ASSIGNED.value,
                    ComplaintStatus.IN_PROGRESS.value,
                    ComplaintStatus.ESCALATED.value,
                ])
            )

        existing_complaints: List[Complaint] = complaints_query.all()

        if not existing_complaints:
            return {
                "is_duplicate": False,
                "confidence": 0.0,
                "primary_complaint_id": None,
                "matches": [],
                "total_candidates_analyzed": 0,
            }

        # Build corpus for TF-IDF
        corpus = [cleaned_query]
        for c in existing_complaints:
            doc = f"{c.title} {c.description}"
            corpus.append(self._clean_text(doc))

        tfidf_matrix = self._vectorizer.fit_transform(corpus)
        query_vec = tfidf_matrix[0]
        candidate_vecs = tfidf_matrix[1:]
        text_cosines = cosine_similarity(query_vec, candidate_vecs)[0]

        matches = []

        for idx, complaint in enumerate(existing_complaints):
            cos_sim = float(text_cosines[idx])
            c_tokens = set(self._clean_text(f"{complaint.title} {complaint.description}").split())
            jaccard_sim = self._jaccard_similarity(query_tokens, c_tokens)
            text_sim = (0.75 * cos_sim) + (0.25 * jaccard_sim)

            # Category score
            cat_score = 0.2
            if category_id and complaint.category_id == category_id:
                cat_score = 1.0
            elif department_id and complaint.department_id == department_id:
                cat_score = 0.6

            # GPS & Distance calculation
            has_gps = (
                latitude is not None
                and longitude is not None
                and complaint.latitude is not None
                and complaint.longitude is not None
            )

            dist_meters = None
            geo_sim = 0.0

            if has_gps:
                dist_meters = haversine_distance(
                    latitude, longitude, complaint.latitude, complaint.longitude
                )
                if dist_meters <= radius:
                    # Decays linearly from 1.0 (at 0m) to 0.0 (at radius)
                    geo_sim = max(0.0, 1.0 - (dist_meters / radius))
                else:
                    geo_sim = 0.0

                # Spatial-Text-Category Fusion
                overall_score = (0.45 * geo_sim) + (0.40 * text_sim) + (0.15 * cat_score)
            else:
                # Text-Category Fusion when GPS is unavailable
                overall_score = (0.80 * text_sim) + (0.20 * cat_score)

            overall_score = round(min(1.0, max(0.0, overall_score)), 3)

            # Record if passes partial candidate threshold (e.g., >= 0.40)
            if overall_score >= 0.40 or (dist_meters is not None and dist_meters <= 50 and text_sim >= 0.35):
                matches.append({
                    "complaint_id": complaint.id,
                    "complaint_number": complaint.complaint_number,
                    "title": complaint.title,
                    "status": complaint.status,
                    "ward": complaint.ward,
                    "distance_meters": round(dist_meters, 1) if dist_meters is not None else None,
                    "text_similarity": round(text_sim, 3),
                    "geo_similarity": round(geo_sim, 3) if has_gps else None,
                    "overall_similarity": overall_score,
                    "created_at": complaint.created_at.isoformat(),
                })

        # Sort matches by overall similarity descending
        matches.sort(key=lambda m: m["overall_similarity"], reverse=True)

        is_duplicate = False
        top_confidence = 0.0
        primary_id = None

        if matches and matches[0]["overall_similarity"] >= threshold:
            is_duplicate = True
            top_confidence = matches[0]["overall_similarity"]
            primary_id = matches[0]["complaint_id"]

        return {
            "is_duplicate": is_duplicate,
            "confidence": top_confidence,
            "primary_complaint_id": primary_id,
            "matches": matches[:10],
            "total_candidates_analyzed": len(existing_complaints),
        }
