import logging
from typing import Optional, Dict, Any
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger

from backend.core.config import settings
from backend.core.database import SessionLocal
from backend.services.escalation_service import check_and_escalate_overdue_complaints

logger = logging.getLogger("civicai.worker")

# Module-level scheduler instance
_scheduler: Optional[BackgroundScheduler] = None
_last_run_summary: Optional[Dict[str, Any]] = None


def run_overdue_check_job() -> Optional[Dict[str, Any]]:
    """
    Scheduled job function executed by APScheduler.
    Creates an isolated database session and executes the overdue escalation engine.
    """
    global _last_run_summary
    db = SessionLocal()
    try:
        logger.info("[Scheduler Job] Starting periodic overdue complaint verification...")
        summary = check_and_escalate_overdue_complaints(db)
        _last_run_summary = summary
        return summary
    except Exception as exc:
        logger.error(f"[Scheduler Job Error] Exception during overdue check: {exc}", exc_info=True)
        _last_run_summary = {"error": str(exc), "status": "failed"}
        return None
    finally:
        db.close()


def get_scheduler() -> BackgroundScheduler:
    """Return the global BackgroundScheduler instance, creating one if not present."""
    global _scheduler
    if _scheduler is None:
        _scheduler = BackgroundScheduler(daemon=True)
    return _scheduler


def start_scheduler() -> None:
    """Start the APScheduler background escalation worker."""
    scheduler = get_scheduler()
    if scheduler.running:
        logger.info("Escalation scheduler is already running.")
        return

    interval_sec = max(5, settings.ESCALATION_CHECK_INTERVAL_SECONDS)
    scheduler.add_job(
        run_overdue_check_job,
        trigger=IntervalTrigger(seconds=interval_sec),
        id="overdue_complaint_checker",
        name="CivicAI Automatic Overdue Escalation Checker",
        replace_existing=True,
        max_instances=1,  # Prevent overlapping execution runs
    )
    scheduler.start()
    logger.info(
        f"Started CivicAI Escalation Scheduler (Interval: {interval_sec}s, DEV_MODE: {settings.DEV_MODE})"
    )


def shutdown_scheduler() -> None:
    """Gracefully shutdown the scheduler."""
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info("CivicAI Escalation Scheduler stopped.")
        _scheduler = None


def get_worker_status() -> Dict[str, Any]:
    """Retrieve operational health metrics of the escalation background worker."""
    scheduler = get_scheduler()
    job = scheduler.get_job("overdue_complaint_checker") if scheduler.running else None
    return {
        "running": scheduler.running,
        "interval_seconds": settings.ESCALATION_CHECK_INTERVAL_SECONDS,
        "dev_mode": settings.DEV_MODE,
        "next_run_time": job.next_run_time.isoformat() if job and job.next_run_time else None,
        "last_run_summary": _last_run_summary,
    }

