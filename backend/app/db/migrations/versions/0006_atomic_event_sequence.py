"""Add an atomic per-task event counter.

Revision ID: 0006_atomic_event_sequence
Revises: 0005_execution_lease_state
"""
import sqlalchemy as sa
from alembic import op

revision = "0006_atomic_event_sequence"
down_revision = "0005_execution_lease_state"
branch_labels = None
depends_on = None


def upgrade() -> None:
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("tasks")}
    if "event_sequence" not in columns:
        with op.batch_alter_table("tasks") as batch:
            batch.add_column(sa.Column("event_sequence", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("tasks")}
    if "event_sequence" in columns:
        with op.batch_alter_table("tasks") as batch:
            batch.drop_column("event_sequence")

