import re
from typing import Dict, List, Optional, Any
from sqlalchemy.orm import Session

from backend.models.category import ComplaintCategory
from backend.models.enums import ComplaintPriority


# Hazard patterns and point weights
CRITICAL_HAZARDS = [
    (r"\b(live|exposed|hanging|bare)\s+wires?\b", 40, "Live / exposed electrical wiring detected (electrocution hazard)"),
    (r"\b(sparking|sparks|short\s+circuit|transformer\s+fire|electric\s+shock)\b", 38, "Active electrical fire / sparking hazard"),
    (r"\b(open|missing|uncovered|broken)\s+manhole\b", 40, "Open / missing manhole cover (severe fall & fatal accident hazard)"),
    (r"\b(road\s+cave-?in|sinkhole|bridge\s+collapse|collapsed\s+slab)\b", 42, "Structural collapse / road cave-in hazard"),
    (r"\b(contaminated|poisonous|toxic|foul|muddy|sewage)\s+(drinking\s+)?water\b", 35, "Contaminated drinking water supply (public health epidemic risk)"),
    (r"\b(gas\s+leak|chemical\s+leak|toxic\s+fumes)\b", 42, "Toxic gas / chemical hazard"),
    (r"\b(child|pedestrian|elderly|bike|car)\s+(fell|fallen|injured|accident|died)\b", 35, "Physical injury or serious accident already reported"),
]

MODERATE_HAZARDS = [
    (r"\b(dead\s+animal|carcass|decaying\s+corpse)\b", 22, "Decaying carcass / biological sanitary hazard"),
    (r"\b(deep\s+crater|huge\s+pothole|dangerous\s+pothole|deep\s+pothole|pothole|crater)\b", 20, "Road surface pothole / crater hazard"),
    (r"\b(water\s+logging|flooding|stagnant\s+water|overflowing\s+sewage)\b", 18, "Water stagnation / flooding / sewage backflow"),
    (r"\b(complete\s+darkness|pitch\s+dark|all\s+lights\s+off)\b", 16, "Complete street lighting blackout in high-crime / traffic zone"),
    (r"\b(pipe\s+burst|gushing\s+water|high\s+pressure\s+leak)\b", 18, "Major municipal pipeline burst wasting water"),
]

SENSITIVE_ZONES = [
    (r"\b(hospital|emergency|icu|clinic|trauma|ambulance)\b", 18, "Near healthcare facility / hospital emergency route"),
    (r"\b(school|kindergarten|college|university|students|children)\b", 16, "Near educational institution / high child footfall area"),
    (r"\b(railway\s+station|metro\s+station|bus\s+station|terminal)\b", 14, "Near major mass transit hub"),
    (r"\b(market|bazaar|pedestrian\s+crossing|junction|circle|intersection)\b", 12, "High pedestrian density / arterial traffic junction"),
    (r"\b(highway|expressway|ring\s+road|flyover)\b", 14, "Fast-moving arterial road or highway corridor"),
]


class CivicPriorityScorer:
    """
    AI-driven multi-criteria priority scoring engine.
    Calculates an explainable urgency score (0-100) and maps to appropriate SLA tiers.
    """

    def score_complaint(
        self,
        title: str,
        description: str,
        category_id: Optional[int] = None,
        ward: Optional[str] = None,
        address: Optional[str] = None,
        landmark: Optional[str] = None,
        duplicate_count: int = 0,
        db: Optional[Session] = None,
    ) -> Dict[str, Any]:
        """
        Computes dynamic priority score, category level, recommended SLA, and explainability factor list.
        """
        combined_text = f"{title} {description}".lower()
        location_text = f"{ward or ''} {address or ''} {landmark or ''} {combined_text}".lower()

        factors: List[str] = []
        breakdown = {
            "life_safety_points": 0,
            "sensitive_zone_points": 0,
            "crowd_velocity_points": 0,
            "base_category_points": 0,
        }

        # 1. Life Safety & Hazard Evaluation (Max 45)
        hazard_pts = 0
        for pattern, pts, reason in CRITICAL_HAZARDS:
            if re.search(pattern, combined_text):
                hazard_pts = max(hazard_pts, pts)
                factors.append(f"[Life Safety] {reason} (+{pts} pts)")

        if hazard_pts < 30:
            for pattern, pts, reason in MODERATE_HAZARDS:
                if re.search(pattern, combined_text):
                    hazard_pts = max(hazard_pts, pts)
                    factors.append(f"[Hazard] {reason} (+{pts} pts)")

        hazard_pts = min(45, hazard_pts)
        breakdown["life_safety_points"] = hazard_pts

        # 2. Sensitive Infrastructure / Location Evaluation (Max 20)
        zone_pts = 0
        for pattern, pts, reason in SENSITIVE_ZONES:
            if re.search(pattern, location_text):
                if pts > zone_pts:
                    zone_pts = pts
                    factors.append(f"[Vulnerable Zone] {reason} (+{pts} pts)")

        zone_pts = min(20, zone_pts)
        breakdown["sensitive_zone_points"] = zone_pts

        # 3. Crowd Surge & Velocity Evaluation (Max 20)
        crowd_pts = 0
        if duplicate_count >= 5:
            crowd_pts = 20
            factors.append(f"[Crowd Surge] High report velocity: {duplicate_count} citizen reports (+20 pts)")
        elif duplicate_count >= 3:
            crowd_pts = 14
            factors.append(f"[Crowd Surge] Multiple citizen reports: {duplicate_count} reports (+14 pts)")
        elif duplicate_count >= 1:
            crowd_pts = 8
            factors.append(f"[Duplicate Velocity] {duplicate_count} duplicate report(s) nearby (+8 pts)")

        breakdown["crowd_velocity_points"] = crowd_pts

        # 4. Base Category Risk & SLA Factor (Max 15)
        base_cat_pts = 5  # default medium
        cat_sla_hours = 48
        cat_priority: Optional[str] = None
        if db and category_id:
            cat = db.query(ComplaintCategory).filter(ComplaintCategory.id == category_id).first()
            if cat:
                cat_sla_hours = cat.sla_hours
                cat_priority = cat.priority_default
                if cat.priority_default == ComplaintPriority.CRITICAL.value:
                    base_cat_pts = 15
                elif cat.priority_default == ComplaintPriority.HIGH.value:
                    base_cat_pts = 10
                elif cat.priority_default == ComplaintPriority.LOW.value:
                    base_cat_pts = 2
                else:
                    base_cat_pts = 5
                factors.append(f"[Category Default] Standard priority for '{cat.name}' is {cat.priority_default} (+{base_cat_pts} pts)")

        breakdown["base_category_points"] = base_cat_pts

        # Calculate Total Score
        total_score = sum(breakdown.values())
        total_score = max(5, min(100, total_score))

        # Map to Priority & Recommended SLA
        if total_score >= 75:
            priority_level = ComplaintPriority.CRITICAL
            recommended_sla_hours = min(cat_sla_hours, 6)
        elif total_score >= 50:
            priority_level = ComplaintPriority.HIGH
            recommended_sla_hours = min(cat_sla_hours, 24)
        elif total_score >= 25:
            priority_level = ComplaintPriority.MEDIUM
            recommended_sla_hours = min(cat_sla_hours, 48)
        else:
            priority_level = ComplaintPriority.LOW
            recommended_sla_hours = cat_sla_hours

        # The category default priority is a floor: a text score alone must not
        # downgrade a category that the municipality has classified as high risk.
        if cat_priority:
            priority_rank = {
                ComplaintPriority.LOW.value: 0,
                ComplaintPriority.MEDIUM.value: 1,
                ComplaintPriority.HIGH.value: 2,
                ComplaintPriority.CRITICAL.value: 3,
            }
            if priority_rank.get(cat_priority, 1) > priority_rank.get(priority_level.value, 1):
                priority_level = ComplaintPriority(cat_priority)
                recommended_sla_hours = cat_sla_hours

        if not factors:
            factors.append("Standard civic grievance within regular routine SLA thresholds.")

        return {
            "priority_score": total_score,
            "priority_level": priority_level.value,
            "recommended_sla_hours": recommended_sla_hours,
            "factors": factors,
            "score_breakdown": breakdown,
        }
