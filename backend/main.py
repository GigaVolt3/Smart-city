import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from starlette.exceptions import HTTPException as StarletteHTTPException

from backend.core.config import settings
from backend.core.database import Base, SessionLocal, engine
from backend.routers import (
    ai_router,
    analytics_router,
    audit_router,
    auth_router,
    categories_router,
    complaints_router,
    departments_router,
    escalations_router,
    notifications_router,
    users_router,
)
from backend.services.escalation_engine import process_escalations
from backend.services.uploads import uploads_root

logger = logging.getLogger("civicai")


async def _escalation_worker() -> None:
    """Background SLA sweep. Sleeps first so startup is never blocked."""
    while True:
        interval = max(10, settings.ESCALATION_CHECK_INTERVAL_SECONDS)
        await asyncio.sleep(interval)
        if not settings.ESCALATION_ENGINE_ENABLED:
            continue
        db = SessionLocal()
        try:
            events = process_escalations(db)
            if events:
                logger.info("Escalation sweep raised %s complaint(s)", len(events))
        except Exception:  # pragma: no cover - defensive worker guard
            logger.exception("Escalation sweep failed")
            db.rollback()
        finally:
            db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create tables, ensure storage exists, and run the escalation worker."""
    Base.metadata.create_all(bind=engine)
    uploads_root().mkdir(parents=True, exist_ok=True)

    worker = asyncio.create_task(_escalation_worker())
    try:
        yield
    finally:
        worker.cancel()
        try:
            await worker
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title=settings.PROJECT_NAME,
    description=(
        "FastAPI Backend for CivicAI: AI-Powered Smart Civic Grievance and "
        "Escalation System"
    ),
    version="1.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def custom_http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail if isinstance(exc.detail, str) else "HTTP Error",
            "detail": exc.detail,
            "status_code": exc.status_code,
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = []
    for err in exc.errors():
        loc = " -> ".join([str(x) for x in err.get("loc", [])])
        msg = err.get("msg", "Validation error")
        errors.append(f"{loc}: {msg}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "Input Validation Error",
            "detail": "; ".join(errors),
            "errors": exc.errors(),
            "status_code": status.HTTP_422_UNPROCESSABLE_ENTITY,
        },
    )


@app.get("/health", tags=["Health"])
def health_check():
    database_ok = True
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception:  # pragma: no cover - only hit when DB is down
        database_ok = False
    return {
        "status": "healthy" if database_ok else "degraded",
        "service": "CivicAI Backend API",
        "version": "1.1.0",
        "environment": settings.ENVIRONMENT,
        "database": "connected" if database_ok else "unavailable",
    }


@app.get("/", tags=["Health"])
def root_endpoint():
    return {
        "project": "CivicAI — Smart Civic Grievance & Escalation System",
        "version": "1.1.0",
        "docs": "/docs",
        "api_v1": settings.API_V1_STR,
    }


app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(users_router, prefix=settings.API_V1_STR)
app.include_router(departments_router, prefix=settings.API_V1_STR)
app.include_router(categories_router, prefix=settings.API_V1_STR)
app.include_router(complaints_router, prefix=settings.API_V1_STR)
app.include_router(ai_router, prefix=settings.API_V1_STR)
app.include_router(analytics_router, prefix=settings.API_V1_STR)
app.include_router(notifications_router, prefix=settings.API_V1_STR)
app.include_router(escalations_router, prefix=settings.API_V1_STR)
app.include_router(audit_router, prefix=settings.API_V1_STR)

# Uploaded evidence is served read-only from the local storage directory.
app.mount(
    "/uploads",
    StaticFiles(directory=str(uploads_root()), check_dir=False),
    name="uploads",
)
