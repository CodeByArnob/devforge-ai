"""Add lease fencing data and structured execution result storage.

Revision ID: 0005_execution_lease_state
Revises: 0004_worker_leases
"""
import sqlalchemy as sa
from alembic import op


revision = "0005_execution_lease_state"
down_revision = "0004_worker_leases"
branch_labels = None
depends_on = None


def upgrade() -> None:
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("worker_jobs")}
    with op.batch_alter_table("worker_jobs") as batch:
        if "lease_started_at" not in columns:
            batch.add_column(sa.Column("lease_started_at", sa.DateTime(timezone=True), nullable=True))
        if "cancellation_requested_at" not in columns:
            batch.add_column(sa.Column("cancellation_requested_at", sa.DateTime(timezone=True), nullable=True))
        if "result" not in columns:
            batch.add_column(sa.Column("result", sa.JSON(), nullable=False, server_default=sa.text("'{}'")))


def downgrade() -> None:
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("worker_jobs")}
    with op.batch_alter_table("worker_jobs") as batch:
        for column in ("result", "cancellation_requested_at", "lease_started_at"):
            if column in columns:
                batch.drop_column(column)

