"""FastAPI dependencies: current user and role guards."""
from collections.abc import Callable

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.errors import forbidden
from app.models import AppUser
from app.services import auth_service

_settings = get_settings()


def current_user(request: Request, db: Session = Depends(get_db)) -> AppUser:
    raw = request.cookies.get(_settings.session_cookie_name)
    return auth_service.resolve_session(db, raw)


def require_roles(*roles: str) -> Callable[[AppUser], AppUser]:
    """Dependency factory asserting the user holds one of the given roles."""

    def _guard(user: AppUser = Depends(current_user)) -> AppUser:
        if user.role_code not in roles:
            raise forbidden(f"Requires role in {roles}")
        return user

    return _guard
