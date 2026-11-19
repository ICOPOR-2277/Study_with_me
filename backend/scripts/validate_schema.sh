#!/usr/bin/env bash
# Valida el esquema SQL contra una instancia real de PostgreSQL (probado con 16).
#
#   ADMIN_DATABASE_URL=postgresql://usuario:clave@localhost:5432/postgres \
#       ./scripts/validate_schema.sh
#
# Crea una base temporal, aplica 0001_initial_up.sql, ejecuta schema_checks.sql,
# prueba la concurrencia de cupos (dos sesiones a la vez), aplica el "down" y
# borra la base temporal. No toca ninguna otra base de datos.
set -euo pipefail
cd "$(dirname "$0")/.."

ADMIN_URL="${ADMIN_DATABASE_URL:-postgresql:///postgres}"
DB="swm_schema_check_$$"
UP="alembic/sql/0001_initial_up.sql"
DOWN="alembic/sql/0001_initial_down.sql"

# URL de la base temporal: misma conexión que ADMIN_URL pero con otro nombre de base.
base_url() { printf '%s' "$ADMIN_URL" | sed -E "s#/[^/?]*(\?|\$)#/$1\1#"; }
TEST_URL="$(base_url "$DB")"

psql_admin() { psql "$ADMIN_URL" -v ON_ERROR_STOP=1 -X -q "$@"; }
psql_test()  { psql "$TEST_URL"  -v ON_ERROR_STOP=1 -X -q "$@"; }

cleanup() { psql "$ADMIN_URL" -X -q -c "DROP DATABASE IF EXISTS \"$DB\"" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== Servidor: $(psql_admin -At -c 'show server_version')"
psql_admin -c "CREATE DATABASE \"$DB\""

echo "== 1) Aplicando $UP"
psql_test -f "$UP"

echo "== 2) Comprobaciones de tablas, restricciones y triggers"
if psql_test -f scripts/schema_checks.sql >/tmp/swm_checks_out.txt 2>&1; then
  sed -E 's/^psql:[^ ]+ //; s/^NOTICE:  //' /tmp/swm_checks_out.txt | grep -E "^OK" | sed 's/^/   /'
  echo "   (todas las comprobaciones pasaron: $(grep -c 'NOTICE:  OK' /tmp/swm_checks_out.txt))"
else
  cat /tmp/swm_checks_out.txt; echo "   HAY COMPROBACIONES FALLIDAS"; exit 1
fi
rm -f /tmp/swm_checks_out.txt

echo "== 3) Concurrencia: dos personas piden el último cupo a la vez"
psql_test <<'SQL'
DELETE FROM payments; DELETE FROM registrations;
UPDATE meetings SET capacity = 1 WHERE id = '10000000-0000-0000-0000-000000000001';
SQL
( psql_test -c "BEGIN; INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000b'); SELECT pg_sleep(2); COMMIT;" ) &
sleep 0.7
if psql_test -c "INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000c')" 2>/tmp/swm_conc_err.txt; then
  echo "   FALLO: se aceptaron dos inscripciones en una reunión de 1 cupo"; wait; exit 1
fi
wait
grep -q "no tiene cupos" /tmp/swm_conc_err.txt && echo "   OK: la segunda sesión esperó el bloqueo y fue rechazada por falta de cupos"
N="$(psql_test -At -c "SELECT count(*) FROM registrations WHERE meeting_id='10000000-0000-0000-0000-000000000001'")"
[ "$N" = "1" ] && echo "   OK: queda exactamente 1 inscripción" || { echo "   FALLO: hay $N inscripciones"; exit 1; }
rm -f /tmp/swm_conc_err.txt

echo "== 4) Aplicando $DOWN (deshacer)"
psql_test -f "$DOWN"
LEFT="$(psql_test -At -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")"
[ "$LEFT" = "0" ] && echo "   OK: no queda ninguna tabla" || { echo "   FALLO: quedan $LEFT tablas"; exit 1; }

echo "== Esquema validado correctamente"
