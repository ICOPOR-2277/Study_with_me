-- ============================================================================
-- 0002 · Panel administrativo
--   * users.role admite también 'admin'
--   * users.is_active: el administrador puede suspender una cuenta (no puede iniciar sesión)
-- Cada sentencia termina con una línea separadora (ver 0001_initial_up.sql).
-- ============================================================================
ALTER TABLE users DROP CONSTRAINT users_role_ck;
-- @@
ALTER TABLE users ADD CONSTRAINT users_role_ck CHECK (role IN ('student', 'monitor', 'admin'));
-- @@
ALTER TABLE users ADD COLUMN is_active boolean NOT NULL DEFAULT true;
-- @@