"""Password hashing and session-token helpers.

Sessions are server-side: we store only a SHA-256 digest of the opaque bearer
token (user_session.token_hash) and hand the raw token to the client in an
HttpOnly cookie. The raw token is never persisted.
"""
import hashlib
import secrets

from passlib.context import CryptContext

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd.hash(plain)


def verify_password(plain: str, hashed: str | None) -> bool:
    if not hashed:
        return False
    return _pwd.verify(plain, hashed)


def new_session_token() -> str:
    """Return a fresh opaque bearer token (URL-safe, 256 bits)."""
    return secrets.token_urlsafe(32)


def hash_token(raw_token: str) -> str:
    """Digest stored in user_session.token_hash."""
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
