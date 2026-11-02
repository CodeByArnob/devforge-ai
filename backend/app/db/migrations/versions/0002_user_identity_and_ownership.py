"""Add user identity and project ownership.

Revision ID: 0002_user_identity
Revises: 0001_initial
"""
import sqlalchemy as sa
from alembic import op

revision = "0002_user_identity"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("password_hash", sa.String(length=512), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    with op.batch_alter_table("projects") as batch:
        batch.add_column(sa.Column("owner_id", sa.Uuid(), nullable=True))
        batch.create_foreign_key(
            "fk_projects_owner_id_users", "users", ["owner_id"], ["id"], ondelete="RESTRICT"
        )
    op.create_index("ix_projects_owner_id", "projects", ["owner_id"])


def downgrade() -> None:
    op.drop_index("ix_projects_owner_id", table_name="projects")
    with op.batch_alter_table("projects") as batch:
        batch.drop_constraint("fk_projects_owner_id_users", type_="foreignkey")
        batch.drop_column("owner_id")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
