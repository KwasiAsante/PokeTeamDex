"""conftest.py — shared pytest fixtures and test environment setup.

Sets the required environment variables before any app module is imported,
so pydantic-settings can instantiate Settings without hitting a real database.
"""

import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/test")
os.environ.setdefault("SECRET_KEY", "test-secret-key-not-used-in-unit-tests")
