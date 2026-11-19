-- Deshace 0001_initial_up.sql. DESTRUCTIVO: borra todas las tablas y sus datos.
-- Solo se ejecuta con "alembic downgrade", nunca durante un despliegue normal.
DROP TABLE IF EXISTS email_verifications;
-- @@
DROP TABLE IF EXISTS saved_meetings;
-- @@
DROP TABLE IF EXISTS payments;
-- @@
DROP TABLE IF EXISTS registrations;
-- @@
DROP FUNCTION IF EXISTS registrations_guard();
-- @@
DROP TABLE IF EXISTS meetings;
-- @@
DROP TABLE IF EXISTS availability_slots;
-- @@
DROP TABLE IF EXISTS user_interests;
-- @@
DROP TABLE IF EXISTS monitor_subjects;
-- @@
DROP FUNCTION IF EXISTS monitor_subjects_guard();
-- @@
DROP TABLE IF EXISTS subjects;
-- @@
DROP TABLE IF EXISTS users;
-- @@
