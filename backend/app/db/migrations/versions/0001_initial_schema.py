"""Create the initial DevForge schema.

Revision ID: 0001_initial
Revises:
"""
from alembic import op

from app.db import models  # noqa: F401
from app.db.base import Base

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # checkfirst makes this safe to run against databases created by the
    # earlier development create_all bootstrap while still adding new tables.
    Base.metadata.create_all(bind=op.get_bind(), checkfirst=True)


def downgrade() -> None:
    Base.metadata.drop_all(bind=op.get_bind(), checkfirst=True)
