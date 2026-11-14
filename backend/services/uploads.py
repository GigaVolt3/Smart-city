"""Safe local file storage for complaint evidence."""

import re
import uuid
from pathlib import Path
from typing import Tuple

from fastapi import HTTPException, UploadFile, status

from backend.core.config import settings

ALLOWED_MIME_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "application/pdf": ".pdf",
}

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".pdf"}


def _safe_name(name: str) -> str:
    stem = Path(name).stem if name else "evidence"
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", stem).strip("-.") or "evidence"
    return cleaned[:60]


def uploads_root() -> Path:
    root = Path(settings.UPLOAD_DIR)
    if not root.is_absolute():
        root = Path.cwd() / root
    return root


async def save_upload(file: UploadFile, complaint_id: int) -> Tuple[str, int, str]:
    """Persist an uploaded file and return (public_path, size, mime_type).

    Raises HTTPException for unsupported types or oversized payloads.
    """
    content_type = (file.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Only JPEG, PNG, WEBP, HEIC images or PDF documents are accepted",
        )

    data = await file.read()
    max_bytes = settings.MAX_UPLOAD_MB * 1024 * 1024
    if len(data) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty"
        )
    if len(data) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds the {settings.MAX_UPLOAD_MB} MB limit",
        )

    original = file.filename or "evidence"
    extension = Path(original).suffix.lower()
    if extension not in ALLOWED_EXTENSIONS:
        extension = ALLOWED_MIME_TYPES[content_type]

    target_dir = uploads_root() / "complaints" / str(complaint_id)
    target_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex[:12]}-{_safe_name(original)}{extension}"
    target = target_dir / filename
    target.write_bytes(data)

    public_path = f"/uploads/complaints/{complaint_id}/{filename}"
    return public_path, len(data), content_type


def disk_path_for_public_path(public_path: str) -> Path:
    """Map a stored `/uploads/...` URL back to its file on disk."""
    relative = public_path
    if relative.startswith("/uploads/"):
        relative = relative[len("/uploads/") :]
    return uploads_root() / relative
