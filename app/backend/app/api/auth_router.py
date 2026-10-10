"""Authentication endpoints: login, logout, current user."""
from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.deps import current_user
from app.models import AppUser
from app.schemas import LoginIn, UserOut
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])
_settings = get_settings()


@router.post("/login", response_model=UserOut)
def login(body: LoginIn, response: Response, db: Session = Depends(get_db)):
    user = auth_service.authenticate(db, body.email, body.password)
    raw = auth_service.create_session(db, user)
    response.set_cookie(
        key=_settings.session_cookie_name,
        value=raw,
        httponly=True,
        secure=_settings.secure_cookies,
        samesite="lax",
        max_age=_settings.session_ttl_minutes * 60,
        path="/",
    )
    return UserOut.model_validate(user, from_attributes=True)


@router.post("/logout")
def logout(response: Response, db: Session = Depends(get_db)):
    # The dependency is intentionally not required: logout should be idempotent.
    response.delete_cookie(_settings.session_cookie_name, path="/")
    return {"ok": True}


@router.get("/me", response_model=UserOut)
def me(user: AppUser = Depends(current_user)):
    return UserOut.model_validate(user, from_attributes=True)
