import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "alembic"))
from sqlfile import split_statements  # noqa: E402


def load(name):
    """Sentencias sin los comentarios que las encabezan."""
    out = []
    for stmt in split_statements((ROOT / "alembic" / "sql" / name).read_text(encoding="utf-8")):
        lines = stmt.splitlines()
        while lines and (not lines[0].strip() or lines[0].strip().startswith("--")):
            lines.pop(0)
        out.append("\n".join(lines))
    return out


def test_up_and_down_split_into_single_statements():
    for name in ("0001_initial_up.sql", "0001_initial_down.sql"):
        stmts = load(name)
        assert stmts, name
        for s in stmts:
            assert "-- @@" not in s
            # sin '%' (el driver lo interpretaría como parámetro) y sin ';' sueltos fuera de cuerpos de función
            assert "%" not in s
    up = load("0001_initial_up.sql")
    assert sum(s.startswith("CREATE TABLE") for s in up) == 10
    assert any(s.startswith("CREATE FUNCTION monitor_subjects_guard") and s.rstrip().endswith("$$;") for s in up)
    assert any(s.startswith("CREATE FUNCTION registrations_guard") and s.rstrip().endswith("$$;") for s in up)


def test_down_drops_every_table_created_by_up():
    up = "\n".join(load("0001_initial_up.sql"))
    down = "\n".join(load("0001_initial_down.sql"))
    import re
    for table in re.findall(r"CREATE TABLE (\w+)", up):
        assert f"DROP TABLE IF EXISTS {table};" in down, table
