import re
from typing import Dict, List, Optional, Tuple, Any
from sqlalchemy.orm import Session
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from backend.models.category import ComplaintCategory
from backend.models.department import Department
from backend.models.enums import ComplaintPriority


# Municipal Domain Lexicon & Keyword Ontology
MUNICIPAL_ONTOLOGY: Dict[str, Dict[str, Any]] = {
    "POTHOLE": {
        "keywords": [
            "pothole", "potholes", "crater", "craters", "road hole", "tar broken",
            "asphalt broken", "road crater", "deep pit", "bump", "depression in road",
            "road uneven", "caved in", "broken road surface"
        ],
        "weight": 1.5,
        "default_priority": ComplaintPriority.MEDIUM.value,
        "dept_code": "ROADS",
    },
    "DAMAGED_ROAD": {
        "keywords": [
            "damaged road", "trench", "unpaved", "road excavation", "dug up",
            "road cut", "pipeline trench left", "footpath broken", "pavement damaged",
            "divider broken", "asphalt cracked", "road resurfacing"
        ],
        "weight": 1.2,
        "default_priority": ComplaintPriority.MEDIUM.value,
        "dept_code": "ROADS",
    },
    "GARBAGE_ACCUMULATION": {
        "keywords": [
            "garbage", "trash", "waste", "dump", "dustbin", "overflowing bin",
            "litter", "rubbish", "stench", "foul smell", "stinking", "rotting garbage",
            "plastic waste", "uncollected waste", "dump yard", "black spots"
        ],
        "weight": 1.3,
        "default_priority": ComplaintPriority.HIGH.value,
        "dept_code": "SAN",
    },
    "DEAD_ANIMAL": {
        "keywords": [
            "dead animal", "dead dog", "dead cat", "carcass", "dead cow",
            "dead bird", "decaying carcass", "animal body", "rotting corpse", "corpse"
        ],
        "weight": 2.0,
        "default_priority": ComplaintPriority.CRITICAL.value,
        "dept_code": "SAN",
    },
    "STREETLIGHT_BROKEN": {
        "keywords": [
            "streetlight", "street light", "lamp post", "bulb", "dark street",
            "lights off", "not glowing", "flickering light", "night dark", "no light",
            "pole not working", "high mast lamp", "broken lamp"
        ],
        "weight": 1.3,
        "default_priority": ComplaintPriority.MEDIUM.value,
        "dept_code": "ELEC",
    },
    "EXPOSED_WIRING": {
        "keywords": [
            "exposed wire", "live wire", "hanging wire", "sparking", "sparks",
            "electric shock", "short circuit", "open fuse box", "junction box open",
            "transformer sparking", "loose electric cable", "danger wire"
        ],
        "weight": 2.2,
        "default_priority": ComplaintPriority.CRITICAL.value,
        "dept_code": "ELEC",
    },
    "WATER_LEAKAGE": {
        "keywords": [
            "water leakage", "pipe burst", "pipe broken", "water pipe leak",
            "pipeline burst", "water wasting", "gushing water", "leakage on road",
            "water bubbling", "valve leakage", "main water line"
        ],
        "weight": 1.4,
        "default_priority": ComplaintPriority.HIGH.value,
        "dept_code": "WATER",
    },
    "CONTAMINATED_WATER": {
        "keywords": [
            "contaminated water", "dirty water", "muddy water", "black water",
            "smelly tap water", "turbid water", "sewage in drinking water",
            "yellow water", "foul water", "impure water", "cholera risk", "drinking water smell"
        ],
        "weight": 2.0,
        "default_priority": ComplaintPriority.CRITICAL.value,
        "dept_code": "WATER",
    },
    "DRAIN_BLOCKED": {
        "keywords": [
            "drain blocked", "clogged drain", "storm drain", "gutter overflow",
            "choked drain", "silted drain", "water logging", "stagnant water",
            "monsoon flooding", "drainage water on street", "overflowing gutter"
        ],
        "weight": 1.4,
        "default_priority": ComplaintPriority.HIGH.value,
        "dept_code": "DRAIN",
    },
    "OPEN_MANHOLE": {
        "keywords": [
            "open manhole", "missing manhole cover", "manhole lid missing",
            "broken drain slab", "uncovered manhole", "deep manhole",
            "pedestrian trap", "fallen into drain", "chamber cover broken"
        ],
        "weight": 2.2,
        "default_priority": ComplaintPriority.CRITICAL.value,
        "dept_code": "DRAIN",
    },
}


class CivicClassifier:
    """
    AI-powered grievance classifier.
    Combines domain ontology heuristics with TF-IDF cosine similarity against
    database category descriptions to accurately classify civic grievances.
    """

    def __init__(self):
        self._vectorizer = TfidfVectorizer(
            ngram_range=(1, 2),
            stop_words="english",
            lowercase=True,
            token_pattern=r"(?u)\b\w+\b"
        )

    def _clean_text(self, text: str) -> str:
        text = text.lower()
        text = re.sub(r"[^\w\s]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    def _extract_keywords(self, text: str) -> List[str]:
        cleaned = self._clean_text(text)
        found_keywords = set()
        for cat_code, info in MUNICIPAL_ONTOLOGY.items():
            for kw in info["keywords"]:
                if re.search(r"\b" + re.escape(kw) + r"\b", cleaned):
                    found_keywords.add(kw)
        return sorted(list(found_keywords))

    def classify(
        self,
        title: str,
        description: str,
        db: Session,
        department_hint_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Classifies grievance text into predicted category and department.
        Returns top prediction, confidence score, suggested priority, and candidate list.
        """
        full_text = f"{title} {description}".strip()
        cleaned_text = self._clean_text(full_text)
        matched_keywords = self._extract_keywords(full_text)

        # 1. Fetch active categories and departments from database
        categories_query = db.query(ComplaintCategory).filter(ComplaintCategory.is_active == True)
        if department_hint_id:
            categories_query = categories_query.filter(ComplaintCategory.department_id == department_hint_id)
        categories: List[ComplaintCategory] = categories_query.all()

        if not categories:
            # Fallback if no categories in DB
            return {
                "category_id": None,
                "category_code": None,
                "category_name": None,
                "department_id": None,
                "department_code": None,
                "department_name": None,
                "confidence": 0.0,
                "suggested_priority": ComplaintPriority.MEDIUM.value,
                "matched_keywords": matched_keywords,
                "candidates": [],
            }

        # 2. Build Category Corpus for TF-IDF
        corpus = []
        cat_map = {}
        for idx, cat in enumerate(categories):
            # Enrich category text with ontology keywords if matching code
            extra_keywords = ""
            if cat.code in MUNICIPAL_ONTOLOGY:
                extra_keywords = " ".join(MUNICIPAL_ONTOLOGY[cat.code]["keywords"])
            doc_text = f"{cat.name} {cat.code} {cat.description or ''} {extra_keywords}"
            corpus.append(self._clean_text(doc_text))
            cat_map[idx] = cat

        # 3. Vectorize and Compute Cosine Similarities
        corpus.append(cleaned_text)
        tfidf_matrix = self._vectorizer.fit_transform(corpus)
        query_vec = tfidf_matrix[-1]
        category_vecs = tfidf_matrix[:-1]

        cos_scores = cosine_similarity(query_vec, category_vecs)[0]

        # 4. Integrate Ontology Keyword Matches
        scores_with_bonus = []
        for idx, base_score in enumerate(cos_scores):
            cat = cat_map[idx]
            bonus = 0.0
            if cat.code in MUNICIPAL_ONTOLOGY:
                onto_info = MUNICIPAL_ONTOLOGY[cat.code]
                for kw in onto_info["keywords"]:
                    if re.search(r"\b" + re.escape(kw) + r"\b", cleaned_text):
                        bonus += 0.25 * onto_info["weight"]

            combined_score = min(1.0, float(base_score) + bonus)
            scores_with_bonus.append((combined_score, cat))

        # Sort by highest score
        scores_with_bonus.sort(key=lambda x: x[0], reverse=True)

        top_score, top_category = scores_with_bonus[0]
        department: Optional[Department] = db.query(Department).filter(Department.id == top_category.department_id).first()

        # Calibration
        confidence = round(max(0.05, min(0.99, top_score)), 3)

        # Suggested priority
        suggested_priority = top_category.priority_default
        if top_category.code in MUNICIPAL_ONTOLOGY:
            suggested_priority = MUNICIPAL_ONTOLOGY[top_category.code]["default_priority"]

        # Build candidate alternatives list
        candidates = []
        for score, cat in scores_with_bonus[:4]:
            dept = db.query(Department).filter(Department.id == cat.department_id).first()
            candidates.append({
                "category_id": cat.id,
                "category_code": cat.code,
                "category_name": cat.name,
                "department_id": cat.department_id,
                "department_name": dept.name if dept else None,
                "confidence": round(float(score), 3),
            })

        return {
            "category_id": top_category.id,
            "category_code": top_category.code,
            "category_name": top_category.name,
            "department_id": top_category.department_id,
            "department_code": department.code if department else None,
            "department_name": department.name if department else None,
            "confidence": confidence,
            "suggested_priority": suggested_priority,
            "matched_keywords": matched_keywords,
            "candidates": candidates,
        }
