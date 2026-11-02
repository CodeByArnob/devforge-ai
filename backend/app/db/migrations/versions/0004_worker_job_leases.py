"""Create durable worker job leases.

Revision ID: 0004_worker_leases
Revises: 0003_task_approval
"""
import sqlalchemy as sa
from alembic import op

revision = "0004_worker_leases"
down_revision = "0003_task_approval"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The bootstrap migration uses metadata.create_all; tolerate a table
    # already created from current model metadata on a fresh database.
    if "worker_jobs" in sa.inspect(op.get_bind()).get_table_names():
        return
    op.create_table(
        "worker_jobs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("task_id", sa.Uuid(), nullable=False),
        sa.Column(
            "status",
            sa.Enum("queued", "leased", "succeeded", "failed", "cancelled", name="workerjobstatus"),
            nullable=False,
        ),
        sa.Column("attempt", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="3"),
        sa.Column("lease_owner", sa.String(length=128), nullable=True),
        sa.Column("lease_token_hash", sa.String(length=64), nullable=True),
        sa.Column("lease_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.String(length=2000), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("task_id", name="uq_worker_jobs_task_id"),
    )
    op.create_index(
        "ix_worker_jobs_claim", "worker_jobs",
        ["status", "lease_expires_at", "created_at"],
    )


def downgrade() -> None:
    if "worker_jobs" in sa.inspect(op.get_bind()).get_table_names():
        op.drop_index("ix_worker_jobs_claim", table_name="worker_jobs")
        op.drop_table("worker_jobs")
