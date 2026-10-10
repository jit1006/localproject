"""Create or update an application user with a hashed password.

Imported identities have NULL password_hash until provisioned here.

Usage:
    python -m scripts.create_user USER-ID "Full Name" email@example.com ROLE \\
        --password 'secret' [--entity ENT-BRN --department DEP-BRN-DEL | --vendor VND-001]
"""
import argparse

from sqlalchemy import select

from app.db import SessionLocal
from app.models import AppUser
from app.security import hash_password


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("user_id")
    p.add_argument("full_name")
    p.add_argument("email")
    p.add_argument("role", choices=["BUSINESS", "VENDOR", "COMPLIANCE", "FACILITIES"])
    p.add_argument("--password", required=True)
    p.add_argument("--entity")
    p.add_argument("--department")
    p.add_argument("--vendor")
    args = p.parse_args()

    db = SessionLocal()
    try:
        user = db.get(AppUser, args.user_id)
        if user is None:
            user = AppUser(user_id=args.user_id)
            db.add(user)
        user.full_name = args.full_name
        user.email = args.email
        user.role_code = args.role
        user.entity_id = args.entity
        user.department_id = args.department
        user.vendor_id = args.vendor
        user.password_hash = hash_password(args.password)
        user.is_active = True
        db.commit()
        print(f"Provisioned user {args.user_id} ({args.role}).")
    finally:
        db.close()


if __name__ == "__main__":
    main()
