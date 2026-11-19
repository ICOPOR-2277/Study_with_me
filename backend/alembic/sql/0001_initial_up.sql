-- ============================================================================
-- Study With Me · esquema inicial (PostgreSQL 16)
--
-- Cada sentencia termina con una línea separadora (dos guiones, espacio, dos
-- arrobas) porque la migración de Alembic ejecuta una sentencia por vez. psql
-- la ignora (es un comentario), así que este archivo se valida con:
--     psql -f 0001_initial_up.sql
--
-- Convenciones:
--   * Identificadores UUID (gen_random_uuid() viene incluido desde PostgreSQL 13).
--   * Correos y usernames se guardan en minúsculas (lo exige un CHECK).
--   * Fecha y hora de las reuniones son "hora de pared" de la universidad
--     (DATE + TIME sin zona horaria); la zona se define en APP_TIMEZONE.
--   * Valores derivados NO se guardan: cupos disponibles, estado "completada",
--     balance de pagos y estadísticas se calculan con consultas.
-- ============================================================================

-- ---------------------------------------------------------------- users
CREATE TABLE users (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name         text        NOT NULL,
    username          text        NOT NULL,
    email             text        NOT NULL,
    password_hash     text        NOT NULL,
    role              text        NOT NULL,
    email_verified_at timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT users_email_key        UNIQUE (email),
    CONSTRAINT users_username_key     UNIQUE (username),
    CONSTRAINT users_full_name_ck     CHECK (length(btrim(full_name)) BETWEEN 1 AND 120),
    CONSTRAINT users_username_ck      CHECK (username ~ '^[a-z0-9_.]{3,30}$'),
    CONSTRAINT users_email_ck         CHECK (email = lower(email) AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' AND length(email) <= 254),
    CONSTRAINT users_role_ck          CHECK (role IN ('student', 'monitor'))
);
-- @@

-- ------------------------------------------------------------- subjects
CREATE TABLE subjects (
    id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    CONSTRAINT subjects_name_key UNIQUE (name),
    CONSTRAINT subjects_name_ck  CHECK (length(btrim(name)) BETWEEN 1 AND 60)
);
-- @@

-- Las 6 materias de la app (las mismas que usa Flutter en AppState.subjects).
INSERT INTO subjects (name) VALUES
    ('Cálculo'), ('Programación'), ('Física'),
    ('Inglés'), ('Bases de datos'), ('Matemáticas')
ON CONFLICT (name) DO NOTHING;
-- @@

-- ---------------------------------------------- monitor_subjects (dominio)
-- "Materias que dominas" del registro de un monitor (máximo 3).
CREATE TABLE monitor_subjects (
    user_id    uuid NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    subject_id uuid NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
    PRIMARY KEY (user_id, subject_id)
);
-- @@

CREATE FUNCTION monitor_subjects_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_role  text;
    v_count integer;
BEGIN
    -- Bloquea la fila del usuario para que dos inserciones simultáneas no superen el límite.
    SELECT role INTO v_role FROM users WHERE id = NEW.user_id FOR UPDATE;
    IF v_role IS DISTINCT FROM 'monitor' THEN
        RAISE EXCEPTION 'Solo un monitor puede tener materias de dominio';
    END IF;
    SELECT count(*) INTO v_count FROM monitor_subjects WHERE user_id = NEW.user_id;
    IF v_count >= 3 THEN
        RAISE EXCEPTION 'Un monitor puede tener como máximo 3 materias';
    END IF;
    RETURN NEW;
END;
$$;
-- @@

CREATE TRIGGER monitor_subjects_guard_trg
    BEFORE INSERT ON monitor_subjects
    FOR EACH ROW EXECUTE FUNCTION monitor_subjects_guard();
-- @@

-- ------------------------------------------------------ user_interests
-- Materias que le interesa aprender a la persona (alimenta las recomendaciones).
CREATE TABLE user_interests (
    user_id    uuid NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    subject_id uuid NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
    PRIMARY KEY (user_id, subject_id)
);
-- @@

-- --------------------------------------------------- availability_slots
-- Franjas semanales en las que la persona puede estudiar.
-- weekday: 0 = lunes ... 6 = domingo (igual que date.weekday() de Python).
CREATE TABLE availability_slots (
    id         uuid     PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid     NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weekday    smallint NOT NULL,
    start_time time     NOT NULL,
    end_time   time     NOT NULL,
    CONSTRAINT availability_weekday_ck CHECK (weekday BETWEEN 0 AND 6),
    CONSTRAINT availability_range_ck   CHECK (end_time > start_time),
    CONSTRAINT availability_slot_key   UNIQUE (user_id, weekday, start_time, end_time)
);
-- @@

-- ------------------------------------------------------------- meetings
CREATE TABLE meetings (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id   uuid        NOT NULL REFERENCES users(id)    ON DELETE RESTRICT,
    subject_id   uuid        NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
    title        text        NOT NULL,
    description  text        NOT NULL DEFAULT '',
    meeting_date date        NOT NULL,
    start_time   time        NOT NULL,
    end_time     time        NOT NULL,
    is_virtual   boolean     NOT NULL DEFAULT false,
    location     text        NOT NULL,
    capacity     integer     NOT NULL,
    price_cop    integer     NOT NULL DEFAULT 0,
    status       text        NOT NULL DEFAULT 'scheduled',
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT meetings_title_ck    CHECK (length(btrim(title)) BETWEEN 1 AND 120),
    CONSTRAINT meetings_location_ck CHECK (length(btrim(location)) BETWEEN 1 AND 255),
    CONSTRAINT meetings_time_ck     CHECK (end_time > start_time),
    CONSTRAINT meetings_capacity_ck CHECK (capacity BETWEEN 1 AND 500),
    CONSTRAINT meetings_price_ck    CHECK (price_cop >= 0),
    CONSTRAINT meetings_status_ck   CHECK (status IN ('scheduled', 'cancelled'))
);
-- @@

CREATE INDEX meetings_date_idx    ON meetings (meeting_date, start_time) WHERE status = 'scheduled';
-- @@
CREATE INDEX meetings_subject_idx ON meetings (subject_id);
-- @@
CREATE INDEX meetings_creator_idx ON meetings (creator_id);
-- @@

-- -------------------------------------------------------- registrations
-- Participantes: una fila por persona inscrita en una reunión.
CREATE TABLE registrations (
    meeting_id uuid        NOT NULL REFERENCES meetings(id) ON DELETE RESTRICT,
    user_id    uuid        NOT NULL REFERENCES users(id)    ON DELETE RESTRICT,
    joined_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (meeting_id, user_id)
);
-- @@

CREATE INDEX registrations_user_idx ON registrations (user_id);
-- @@

-- Red de seguridad de integridad (la API valida antes y devuelve mensajes claros):
-- bloquea la reunión, y rechaza cancelada, propia o sin cupos.
CREATE FUNCTION registrations_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_capacity integer;
    v_status   text;
    v_creator  uuid;
    v_taken    integer;
BEGIN
    SELECT capacity, status, creator_id INTO v_capacity, v_status, v_creator
      FROM meetings WHERE id = NEW.meeting_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN NEW; -- la clave foránea reportará el error
    END IF;
    IF v_status <> 'scheduled' THEN
        RAISE EXCEPTION 'La reunión no está disponible';
    END IF;
    IF v_creator = NEW.user_id THEN
        RAISE EXCEPTION 'No puedes inscribirte en tu propia reunión';
    END IF;
    SELECT count(*) INTO v_taken FROM registrations WHERE meeting_id = NEW.meeting_id;
    IF v_taken >= v_capacity THEN
        RAISE EXCEPTION 'La reunión no tiene cupos disponibles';
    END IF;
    RETURN NEW;
END;
$$;
-- @@

CREATE TRIGGER registrations_guard_trg
    BEFORE INSERT ON registrations
    FOR EACH ROW EXECUTE FUNCTION registrations_guard();
-- @@

-- ------------------------------------------------------------- payments
-- Pagos SIMULADOS: se guarda el monto al inscribirse en una reunión de pago,
-- pero no existe ninguna pasarela ni cobro real. Una reunión gratis no genera fila.
-- Quién recibe el dinero es el creador de la reunión (no se duplica aquí).
CREATE TABLE payments (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id uuid        NOT NULL,
    payer_id   uuid        NOT NULL,
    amount_cop integer     NOT NULL,
    status     text        NOT NULL DEFAULT 'simulated',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payments_registration_fk FOREIGN KEY (meeting_id, payer_id)
        REFERENCES registrations (meeting_id, user_id) ON DELETE RESTRICT,
    CONSTRAINT payments_one_per_registration UNIQUE (meeting_id, payer_id),
    CONSTRAINT payments_amount_ck CHECK (amount_cop > 0),
    CONSTRAINT payments_status_ck CHECK (status IN ('simulated'))
);
-- @@

CREATE INDEX payments_payer_idx ON payments (payer_id, created_at);
-- @@

-- ------------------------------------------------------ saved_meetings
CREATE TABLE saved_meetings (
    user_id    uuid        NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    meeting_id uuid        NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    saved_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, meeting_id)
);
-- @@

-- --------------------------------------------------- email_verifications
-- Se guarda un HMAC del código de 6 dígitos, nunca el código.
CREATE TABLE email_verifications (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash   text        NOT NULL,
    expires_at  timestamptz NOT NULL,
    attempts    smallint    NOT NULL DEFAULT 0,
    consumed_at timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT email_verifications_attempts_ck CHECK (attempts >= 0)
);
-- @@

CREATE INDEX email_verifications_user_idx ON email_verifications (user_id, created_at DESC);
-- @@
