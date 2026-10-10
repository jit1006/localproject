"""PRMS FastAPI application entrypoint."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api import (
    auth_router,
    carton_router,
    dashboard_router,
    hold_router,
    reconciliation_router,
    request_router,
)
from app.config import get_settings
from app.db import engine
from app.errors import AppError, app_error_handler

_settings = get_settings()

app = FastAPI(
    title="PRMS API",
    version="0.1.0",
    description="Physical Records Management System — backend API.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[_settings.frontend_origin],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppError, app_error_handler)

API_PREFIX = "/api/v1"
app.include_router(auth_router.router, prefix=API_PREFIX)
app.include_router(carton_router.router, prefix=API_PREFIX)
app.include_router(request_router.router, prefix=API_PREFIX)
app.include_router(hold_router.router, prefix=API_PREFIX)
app.include_router(reconciliation_router.router, prefix=API_PREFIX)
app.include_router(dashboard_router.router, prefix=API_PREFIX)


@app.get("/health", tags=["health"])
def health():
    """Liveness + DB connectivity check."""
    db_ok = False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            db_ok = True
    except Exception:
        db_ok = False
    return {"status": "ok", "database": "up" if db_ok else "down", "env": _settings.environment}
