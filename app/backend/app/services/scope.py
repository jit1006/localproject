"""Row-scope enforcement. Business users see only their department; vendor
users only their vendor; Compliance and Facilities are cross-entity readers.
"""
from app.errors import forbidden
from app.models import AppUser, Carton, ServiceRequest


def assert_can_view_carton(user: AppUser, carton: Carton) -> None:
    if user.role_code in ("FACILITIES", "COMPLIANCE"):
        return
    if user.role_code == "BUSINESS":
        if carton.entity_id == user.entity_id and carton.department_id == user.department_id:
            return
        raise forbidden("Carton belongs to another department")
    if user.role_code == "VENDOR":
        if carton.assigned_vendor_id == user.vendor_id:
            return
        raise forbidden("Carton is not assigned to your vendor")
    raise forbidden()


def assert_can_raise_for_carton(user: AppUser, carton: Carton) -> None:
    """Only the owning Business department may raise service requests."""
    if user.role_code != "BUSINESS":
        raise forbidden("Only Business users can raise requests")
    if carton.entity_id != user.entity_id or carton.department_id != user.department_id:
        raise forbidden("Carton belongs to another department")


def assert_can_act_on_request(user: AppUser, request: ServiceRequest) -> None:
    """Vendor users may only act on their own vendor's requests."""
    if user.role_code != "VENDOR":
        raise forbidden("Only Vendor users can confirm operational actions")
    if request.vendor_id != user.vendor_id:
        raise forbidden("Request is not assigned to your vendor")
