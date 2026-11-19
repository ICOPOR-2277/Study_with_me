-- Comprobaciones del esquema. Se ejecutan con scripts/validate_schema.sh
-- (psql -v ON_ERROR_STOP=1): cualquier "FALLO" aborta con código distinto de 0.

CREATE FUNCTION pg_temp.expect_fail(label text, stmt text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'OK    % -> rechazado (%)', label, SQLERRM;
        RETURN;
    END;
    RAISE EXCEPTION 'FALLO % -> debía ser rechazado y fue aceptado', label;
END;
$$;

CREATE FUNCTION pg_temp.expect_ok(label text, stmt text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE stmt;
    RAISE NOTICE 'OK    % -> aceptado', label;
END;
$$;

CREATE FUNCTION pg_temp.expect_eq(label text, got bigint, want bigint) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF got IS DISTINCT FROM want THEN
        RAISE EXCEPTION 'FALLO % -> esperado %, obtenido %', label, want, got;
    END IF;
    RAISE NOTICE 'OK    % = %', label, got;
END;
$$;

-- 1) Tablas y datos semilla -------------------------------------------------
SELECT pg_temp.expect_eq('tablas creadas',
    (SELECT count(*) FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name IN ('users','subjects','monitor_subjects','user_interests',
                           'availability_slots','meetings','registrations','payments',
                           'saved_meetings','email_verifications')), 10);
SELECT pg_temp.expect_eq('materias semilla', (SELECT count(*) FROM subjects), 6);

-- 2) Usuarios ---------------------------------------------------------------
INSERT INTO users (id, full_name, username, email, password_hash, role, email_verified_at) VALUES
 ('00000000-0000-0000-0000-00000000000a', 'Ana Monitor',  'ana',   'ana@uni.edu',   'x', 'monitor', now()),
 ('00000000-0000-0000-0000-00000000000b', 'Beto Student', 'beto',  'beto@uni.edu',  'x', 'student', now()),
 ('00000000-0000-0000-0000-00000000000c', 'Cami Student', 'cami',  'cami@uni.edu',  'x', 'student', now());

SELECT pg_temp.expect_fail('correo duplicado',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('X','xx1','ana@uni.edu','x','student')$q$);
SELECT pg_temp.expect_fail('username duplicado',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('X','ana','otro@uni.edu','x','student')$q$);
SELECT pg_temp.expect_fail('correo con mayúsculas',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('X','xx2','Otro@uni.edu','x','student')$q$);
SELECT pg_temp.expect_fail('correo sin arroba',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('X','xx3','otro.uni.edu','x','student')$q$);
SELECT pg_temp.expect_fail('username inválido (con @)',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('X','@xx4','x4@uni.edu','x','student')$q$);
SELECT pg_temp.expect_fail('rol inválido',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('X','xx5','x5@uni.edu','x','admin')$q$);
SELECT pg_temp.expect_fail('nombre vacío',
  $q$INSERT INTO users (full_name, username, email, password_hash, role) VALUES ('   ','xx6','x6@uni.edu','x','student')$q$);

-- 3) Materias del monitor (máx. 3, solo monitores) --------------------------
SELECT pg_temp.expect_fail('estudiante con materias de dominio',
  $q$INSERT INTO monitor_subjects SELECT '00000000-0000-0000-0000-00000000000b', id FROM subjects LIMIT 1$q$);
INSERT INTO monitor_subjects
  SELECT '00000000-0000-0000-0000-00000000000a', id FROM (SELECT id FROM subjects ORDER BY name LIMIT 3) s;
SELECT pg_temp.expect_eq('monitor con 3 materias',
  (SELECT count(*) FROM monitor_subjects WHERE user_id = '00000000-0000-0000-0000-00000000000a'), 3);
SELECT pg_temp.expect_fail('cuarta materia de un monitor',
  $q$INSERT INTO monitor_subjects SELECT '00000000-0000-0000-0000-00000000000a', id FROM subjects
       WHERE id NOT IN (SELECT subject_id FROM monitor_subjects) LIMIT 1$q$);

-- 4) Intereses y disponibilidad ----------------------------------------------
INSERT INTO user_interests SELECT '00000000-0000-0000-0000-00000000000b', id FROM subjects LIMIT 2;
SELECT pg_temp.expect_fail('interés duplicado',
  $q$INSERT INTO user_interests SELECT '00000000-0000-0000-0000-00000000000b', subject_id FROM user_interests LIMIT 1$q$);
SELECT pg_temp.expect_ok('franja válida',
  $q$INSERT INTO availability_slots (user_id, weekday, start_time, end_time) VALUES ('00000000-0000-0000-0000-00000000000b', 0, '14:00', '18:00')$q$);
SELECT pg_temp.expect_fail('franja con fin <= inicio',
  $q$INSERT INTO availability_slots (user_id, weekday, start_time, end_time) VALUES ('00000000-0000-0000-0000-00000000000b', 1, '18:00', '14:00')$q$);
SELECT pg_temp.expect_fail('día de la semana 7',
  $q$INSERT INTO availability_slots (user_id, weekday, start_time, end_time) VALUES ('00000000-0000-0000-0000-00000000000b', 7, '08:00', '09:00')$q$);
SELECT pg_temp.expect_fail('franja duplicada',
  $q$INSERT INTO availability_slots (user_id, weekday, start_time, end_time) VALUES ('00000000-0000-0000-0000-00000000000b', 0, '14:00', '18:00')$q$);

-- 5) Reuniones -----------------------------------------------------------------
INSERT INTO meetings (id, creator_id, subject_id, title, meeting_date, start_time, end_time, is_virtual, location, capacity, price_cop)
SELECT '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', id,
       'Derivadas', current_date + 3, '09:00', '11:00', false, 'Biblioteca', 2, 15000
  FROM subjects WHERE name = 'Cálculo';
INSERT INTO meetings (id, creator_id, subject_id, title, meeting_date, start_time, end_time, is_virtual, location, capacity, price_cop)
SELECT '10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000b', id,
       'Python', current_date + 4, '14:00', '15:00', true, 'Meet', 1, 0
  FROM subjects WHERE name = 'Programación';

SELECT pg_temp.expect_fail('reunión con fin <= inicio',
  $q$INSERT INTO meetings (creator_id, subject_id, title, meeting_date, start_time, end_time, location, capacity)
       SELECT creator_id, subject_id, 't', current_date, '10:00', '10:00', 'x', 1 FROM meetings LIMIT 1$q$);
SELECT pg_temp.expect_fail('capacidad 0',
  $q$INSERT INTO meetings (creator_id, subject_id, title, meeting_date, start_time, end_time, location, capacity)
       SELECT creator_id, subject_id, 't', current_date, '10:00', '11:00', 'x', 0 FROM meetings LIMIT 1$q$);
SELECT pg_temp.expect_fail('precio negativo',
  $q$INSERT INTO meetings (creator_id, subject_id, title, meeting_date, start_time, end_time, location, capacity, price_cop)
       SELECT creator_id, subject_id, 't', current_date, '10:00', '11:00', 'x', 1, -5 FROM meetings LIMIT 1$q$);
SELECT pg_temp.expect_fail('estado inválido',
  $q$INSERT INTO meetings (creator_id, subject_id, title, meeting_date, start_time, end_time, location, capacity, status)
       SELECT creator_id, subject_id, 't', current_date, '10:00', '11:00', 'x', 1, 'borrada' FROM meetings LIMIT 1$q$);
SELECT pg_temp.expect_fail('título vacío',
  $q$INSERT INTO meetings (creator_id, subject_id, title, meeting_date, start_time, end_time, location, capacity)
       SELECT creator_id, subject_id, ' ', current_date, '10:00', '11:00', 'x', 1 FROM meetings LIMIT 1$q$);
SELECT pg_temp.expect_fail('creador inexistente',
  $q$INSERT INTO meetings (creator_id, subject_id, title, meeting_date, start_time, end_time, location, capacity)
       SELECT '99999999-9999-9999-9999-999999999999', subject_id, 't', current_date, '10:00', '11:00', 'x', 1 FROM meetings LIMIT 1$q$);

-- 6) Inscripciones (participantes) y cupos -------------------------------------
SELECT pg_temp.expect_fail('inscribirse en su propia reunión',
  $q$INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a')$q$);
INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
SELECT pg_temp.expect_fail('inscripción duplicada',
  $q$INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b')$q$);
INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c');
-- capacidad 2 ya llena: un tercer usuario no cabe
INSERT INTO users (id, full_name, username, email, password_hash, role, email_verified_at)
  VALUES ('00000000-0000-0000-0000-00000000000d', 'Dani Student', 'dani', 'dani@uni.edu', 'x', 'student', now());
SELECT pg_temp.expect_fail('reunión llena',
  $q$INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d')$q$);
UPDATE meetings SET status = 'cancelled' WHERE id = '10000000-0000-0000-0000-000000000002';
SELECT pg_temp.expect_fail('reunión cancelada',
  $q$INSERT INTO registrations (meeting_id, user_id) VALUES ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000c')$q$);
SELECT pg_temp.expect_eq('cupos usados en la reunión 1',
  (SELECT count(*) FROM registrations WHERE meeting_id = '10000000-0000-0000-0000-000000000001'), 2);

-- 7) Pagos simulados ------------------------------------------------------------
SELECT pg_temp.expect_fail('pago sin inscripción',
  $q$INSERT INTO payments (meeting_id, payer_id, amount_cop) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d', 15000)$q$);
SELECT pg_temp.expect_fail('pago de monto 0',
  $q$INSERT INTO payments (meeting_id, payer_id, amount_cop) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 0)$q$);
SELECT pg_temp.expect_fail('estado de pago inválido',
  $q$INSERT INTO payments (meeting_id, payer_id, amount_cop, status) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 1, 'captured')$q$);
INSERT INTO payments (meeting_id, payer_id, amount_cop) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 15000);
SELECT pg_temp.expect_fail('segundo pago de la misma inscripción',
  $q$INSERT INTO payments (meeting_id, payer_id, amount_cop) VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 15000)$q$);

-- 8) Guardadas y verificación de correo ---------------------------------------
INSERT INTO saved_meetings (user_id, meeting_id) VALUES ('00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-000000000001');
SELECT pg_temp.expect_fail('guardada duplicada',
  $q$INSERT INTO saved_meetings (user_id, meeting_id) VALUES ('00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-000000000001')$q$);
INSERT INTO email_verifications (user_id, code_hash, expires_at)
  VALUES ('00000000-0000-0000-0000-00000000000d', 'hash', now() + interval '10 minutes');
SELECT pg_temp.expect_fail('intentos negativos',
  $q$INSERT INTO email_verifications (user_id, code_hash, expires_at, attempts) VALUES ('00000000-0000-0000-0000-00000000000d', 'h', now(), -1)$q$);

-- 9) Borrados: no se pierde historial; lo accesorio se limpia en cascada -----------
SELECT pg_temp.expect_fail('borrar un usuario con reuniones/inscripciones',
  $q$DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000b'$q$);
DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000d';
SELECT pg_temp.expect_eq('borrado en cascada de guardadas y verificaciones',
  (SELECT count(*) FROM saved_meetings WHERE user_id = '00000000-0000-0000-0000-00000000000d')
  + (SELECT count(*) FROM email_verifications WHERE user_id = '00000000-0000-0000-0000-00000000000d'), 0);
SELECT pg_temp.expect_fail('borrar una materia en uso',
  $q$DELETE FROM subjects WHERE id IN (SELECT subject_id FROM meetings LIMIT 1)$q$);
