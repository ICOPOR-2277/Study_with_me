"""panel administrativo: rol admin y cuentas suspendibles

Revision ID: 0002
Revises: 0001
"""
import sys
from pathlib import Path

from alembic import op

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sqlfile import run_sql_file  # noqa: E402

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    run_sql_file(op, "0002_admin_up.sql")


def downgrade() -> None:
    run_sql_file(op, "0002_admin_down.sql")