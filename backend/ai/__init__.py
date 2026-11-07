"""
CivicAI - Artificial Intelligence Module
Powers civic grievance intelligence:
1. Complaint Classification (Category & Department prediction)
2. Duplicate Complaint Detection (Text similarity + GPS proximity)
3. AI-Based Priority Scoring (Urgency, life safety, crowd velocity, sensitive zones)
4. Recurring Issue Hotspot Detection (DBSCAN spatial clustering & chronic recurrence scoring)
5. Before-and-After Image Comparison (Resolution verification & anti-fraud detection)
"""

from backend.ai.classifier import CivicClassifier
from backend.ai.duplicate_detector import DuplicateDetector
from backend.ai.priority_scorer import CivicPriorityScorer
from backend.ai.hotspot_detector import CivicHotspotDetector
from backend.ai.image_comparator import CivicImageComparator

__all__ = [
    "CivicClassifier",
    "DuplicateDetector",
    "CivicPriorityScorer",
    "CivicHotspotDetector",
    "CivicImageComparator",
]
