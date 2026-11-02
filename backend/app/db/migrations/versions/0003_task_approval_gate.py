"""Add explicit human approval decision fields to tasks.

Revision ID: 0003_task_approval
Revises: 0002_user_identity
"""
import sqlalchemy as sa
from alembic import op

revision = "0003_task_approval"
down_revision = "0002_user_identity"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("approval_decision", sa.String(length=16), nullable=False,
                  server_default="not_required"),
    )
    op.add_column("tasks", sa.Column("approval_note", sa.String(length=2000), nullable=True))
    op.add_column("tasks", sa.Column("approval_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("tasks", "approval_at")
    op.drop_column("tasks", "approval_note")
    op.drop_column("tasks", "approval_decision")
