"""Authentication and session lifecycle."""
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.errors import unauthorized
from app.models import AppUser, UserSession
from app.security import hash_token, new_session_token, verify_password

_settings = get_settings()


def authenticate(db: Session, email: str, password: str) -> AppUser:
    user = db.scalar(select(AppUser).where(AppUser.email.ilike(email)))
    if user is None or not user.is_active or not verify_password(password, user.password_hash):
        # Uniform message: never reveal whether the email exists.
        raise unauthorized("Invalid email or password")
    return user


def create_session(db: Session, user: AppUser) -> str:
    """Create a server-side session and return the raw bearer token."""
    raw = new_session_token()
    now = datetime.now(timezone.utc)
    db.add(
        UserSession(
            token_hash=hash_token(raw),
            user_id=user.user_id,
            expires_at=now + timedelta(minutes=_settings.session_ttl_minutes),
        )
    )
    db.commit()
    return raw


def resolve_session(db: Session, raw_token: str | None) -> AppUser:
    if not raw_token:
        raise unauthorized()
    row = db.get(UserSession, hash_token(raw_token))
    now = datetime.now(timezone.utc)
    if row is None or row.revoked_at is not None or row.expires_at <= now:
        raise unauthorized("Session expired or invalid")
    user = db.get(AppUser, row.user_id)
    if user is None or not user.is_active:
        raise unauthorized("Account is inactive")
    return user


def revoke_session(db: Session, raw_token: str | None) -> None:
    if not raw_token:
        return
    row = db.get(UserSession, hash_token(raw_token))
    if row and row.revoked_at is None:
        row.revoked_at = datetime.now(timezone.utc)
        db.commit()
