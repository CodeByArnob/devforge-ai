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
    # The bootstrap migration historically used metadata.create_all, which can
    # create columns from current models before this additive migration runs.
    existing = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("tasks")}
    if "approval_decision" not in existing:
        op.add_column(
            "tasks",
            sa.Column(
                "approval_decision", sa.String(length=16), nullable=False,
                server_default="not_required",
            ),
        )
    if "approval_note" not in existing:
        op.add_column("tasks", sa.Column("approval_note", sa.String(length=2000), nullable=True))
    if "approval_at" not in existing:
        op.add_column("tasks", sa.Column("approval_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    existing = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("tasks")}
    if "approval_at" in existing:
        op.drop_column("tasks", "approval_at")
    if "approval_note" in existing:
        op.drop_column("tasks", "approval_note")
    if "approval_decision" in existing:
        op.drop_column("tasks", "approval_decision")
