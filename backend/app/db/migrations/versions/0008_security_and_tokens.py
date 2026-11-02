"""Add password reset tokens, revoked tokens, and rate limits.

Revision ID: 0008_security_and_tokens
Revises: 0007_patch_proposals
"""
import sqlalchemy as sa
from alembic import op

revision = "0008_security_and_tokens"
down_revision = "0007_patch_proposals"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "password_reset_tokens" not in tables:
        op.create_table(
            "password_reset_tokens",
            sa.Column("id", sa.Uuid(), primary_key=True),
            sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("token_hash", sa.String(64), nullable=False, unique=True),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_reset_token_user_expires", "password_reset_tokens", ["user_id", "expires_at"])
    else:
        indexes = {item["name"] for item in sa.inspect(bind).get_indexes("password_reset_tokens")}
        if "ix_reset_token_user_expires" not in indexes:
            op.create_index("ix_reset_token_user_expires", "password_reset_tokens", ["user_id", "expires_at"])

    if "revoked_tokens" not in tables:
        op.create_table(
            "revoked_tokens",
            sa.Column("id", sa.Uuid(), primary_key=True),
            sa.Column("jti", sa.String(64), nullable=False, unique=True),
            sa.Column("token_type", sa.String(16), nullable=False, server_default="access"),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_revoked_tokens_expires", "revoked_tokens", ["expires_at"])
    else:
        indexes = {item["name"] for item in sa.inspect(bind).get_indexes("revoked_tokens")}
        if "ix_revoked_tokens_expires" not in indexes:
            op.create_index("ix_revoked_tokens_expires", "revoked_tokens", ["expires_at"])

    if "rate_limit_records" not in tables:
        op.create_table(
            "rate_limit_records",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("rate_key", sa.String(128), nullable=False),
            sa.Column("endpoint", sa.String(128), nullable=False),
            sa.Column("count", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("rate_key", "endpoint", name="uq_rate_limit_key_endpoint"),
        )
        op.create_index("ix_rate_limit_key_endpoint", "rate_limit_records", ["rate_key", "endpoint"])
    else:
        indexes = {item["name"] for item in sa.inspect(bind).get_indexes("rate_limit_records")}
        if "ix_rate_limit_key_endpoint" not in indexes:
            op.create_index("ix_rate_limit_key_endpoint", "rate_limit_records", ["rate_key", "endpoint"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "rate_limit_records" in tables:
        op.drop_table("rate_limit_records")

    if "revoked_tokens" in tables:
        op.drop_table("revoked_tokens")

    if "password_reset_tokens" in tables:
        op.drop_table("password_reset_tokens")
