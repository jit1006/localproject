"""Standard error shape: code, message, field errors, correlation id."""
from fastapi import Request
from fastapi.responses import JSONResponse


class AppError(Exception):
    """Business/domain error with a stable code and HTTP status."""

    def __init__(self, code: str, message: str, status_code: int = 400, field_errors: dict | None = None):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.field_errors = field_errors or {}
        super().__init__(message)


# Convenience constructors for common cases.
def not_found(message: str = "Resource not found") -> AppError:
    return AppError("NOT_FOUND", message, 404)


def forbidden(message: str = "You do not have access to this resource") -> AppError:
    return AppError("FORBIDDEN", message, 403)


def unauthorized(message: str = "Authentication required") -> AppError:
    return AppError("UNAUTHORIZED", message, 401)


def conflict(message: str) -> AppError:
    return AppError("CONFLICT", message, 409)


def unprocessable(message: str, field_errors: dict | None = None) -> AppError:
    return AppError("UNPROCESSABLE", message, 422, field_errors)


async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    correlation_id = request.headers.get("x-correlation-id", "n/a")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": exc.code,
                "message": exc.message,
                "fieldErrors": exc.field_errors,
                "correlationId": correlation_id,
            }
        },
    )
