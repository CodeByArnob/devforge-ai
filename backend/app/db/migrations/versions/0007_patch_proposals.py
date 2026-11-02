"""Add reviewable patch proposals.

Revision ID: 0007_patch_proposals
Revises: 0006_atomic_event_sequence
"""
import sqlalchemy as sa
from alembic import op

revision = "0007_patch_proposals"
down_revision = "0006_atomic_event_sequence"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if "patch_proposals" in sa.inspect(op.get_bind()).get_table_names():
        return
    op.create_table(
        "patch_proposals", sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("task_id", sa.Uuid(), sa.ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("base_snapshot_digest", sa.String(64), nullable=False),
        sa.Column("patch_digest", sa.String(64), nullable=False), sa.Column("changes", sa.JSON(), nullable=False),
        sa.Column("unified_diff", sa.Text(), nullable=False), sa.Column("status", sa.String(16), nullable=False),
        sa.Column("applied_snapshot_digest", sa.String(64)), sa.Column("approval_note", sa.String(2000)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False), sa.Column("approved_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_patch_proposals_task_created", "patch_proposals", ["task_id", "created_at"])


def downgrade() -> None:
    if "patch_proposals" in sa.inspect(op.get_bind()).get_table_names():
        op.drop_index("ix_patch_proposals_task_created", table_name="patch_proposals")
        op.drop_table("patch_proposals")

