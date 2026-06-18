"""conftest.py — shared pytest fixtures and test environment setup.

Sets the required environment variables before any app module is imported,
so pydantic-settings can instantiate Settings without hitting a real database.
"""

import os

import pytest
from unittest.mock import AsyncMock, MagicMock

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/test")
os.environ.setdefault("SECRET_KEY", "test-secret-key-not-used-in-unit-tests")


@pytest.fixture
def async_db_session():
    """A mock AsyncSession for unit tests that don't need a real database.

    Returns a MagicMock that stubs out the SQLAlchemy async patterns used
    in PokemonResolverService.resolve() and related helpers.
    """
    session = MagicMock()
    # execute() returns an awaitable whose scalar_one_or_none() returns None
    # (cache miss), so the resolver proceeds to fetch from PokéAPI.
    execute_result = MagicMock()
    execute_result.scalar_one_or_none.return_value = None
    session.execute = AsyncMock(return_value=execute_result)
    session.commit = AsyncMock()
    return session
