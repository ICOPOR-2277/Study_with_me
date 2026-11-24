-- Deshace 0002_admin_up.sql. Los administradores pasan a 'student' (no se borra ninguna cuenta).
ALTER TABLE users DROP COLUMN is_active;
-- @@
UPDATE users SET role = 'student' WHERE role = 'admin';
-- @@
ALTER TABLE users DROP CONSTRAINT users_role_ck;
-- @@
ALTER TABLE users ADD CONSTRAINT users_role_ck CHECK (role IN ('student', 'monitor'));
-- @@