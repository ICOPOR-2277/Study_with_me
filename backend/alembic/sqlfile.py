"""Ayuda para migraciones escritas en SQL: lee un .sql y lo ejecuta sentencia por sentencia.

Las sentencias se separan con una línea '-- @@' (psql la ignora, porque es un comentario).
"""
from pathlib import Path

SEPARATOR = "-- @@"
SQL_DIR = Path(__file__).parent / "sql"


def split_statements(sql: str) -> list[str]:
    parts = [chunk.strip() for chunk in sql.split(SEPARATOR)]
    return [p for p in parts if any(line.strip() and not line.strip().startswith("--") for line in p.splitlines())]


def run_sql_file(op, name: str) -> None:
    for stmt in split_statements((SQL_DIR / name).read_text(encoding="utf-8")):
        op.get_bind().exec_driver_sql(stmt)
