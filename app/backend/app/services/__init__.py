"""Business services: all state-changing logic and permission checks live here.

API routers must not touch the database directly; they call services, which
enforce authentication, role, row-scope and field permissions on the server.
"""
