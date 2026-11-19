# Study With Me — Estado del proyecto
Actualizado: 17 nov 2026. Léelo completo antes de continuar en otra sesión o cuenta.

## 1. Arquitectura final
```
Flutter (frontend/)  --HTTP/JSON + JWT-->  FastAPI (backend/app)  --SQLAlchemy-->  PostgreSQL 16
```
Flutter nunca toca la base de datos. Tres servicios independientes en Render (`render.yaml`): base de datos, API, Flutter Web estático.

| Capa | Tecnología |
|---|---|
| Frontend | Flutter / Dart ≥3.0, Material 3, `ChangeNotifier`, paquete `http` |
| API | Python 3.12+, FastAPI, Pydantic v2, SQLAlchemy 2.0 (síncrono), psycopg 3, Alembic, PyJWT |
| BD | PostgreSQL 16 (UUID, CHECK, triggers) |
| Contraseñas | scrypt de la librería estándar (`hashlib.scrypt`, N=2^15, r=8, p=1), parámetros dentro del hash |
| Sesión | JWT HS256, 12 h por defecto, sin refresh token |

## 2. Estructura
```
render.yaml                 Blueprint de Render (BD + API + web)
ESTADO_PROYECTO.md          este archivo
backend/
  app/main.py               crea la app, CORS, manejo de errores; punto de entrada uvicorn
  app/core/                 config.py (variables de entorno), security.py (hash/JWT/códigos),
                            deps.py (usuario autenticado, "ahora"), errors.py, timeutil.py
  app/db/                   base.py, session.py (motor y sesión)
  app/models/               users/monitor_subjects/interests/availability/email_verifications,
                            subjects, meetings/registrations/payments/saved_meetings
  app/schemas/              contratos JSON (Pydantic): user.py, meeting.py, common.py
  app/services/             lógica: auth, user, meeting, report (calendario/historial/resumen),
                            recommendation (pura), email, subject
  app/routers/              auth, users, subjects, meetings, reports
  alembic/                  env.py, versions/0001_initial.py, sql/0001_initial_{up,down}.sql, sqlfile.py
  scripts/                  validate_schema.sh + schema_checks.sql
  tests/unit/               30 pruebas ejecutables sin FastAPI/BD
  tests/integration/        pruebas de la API con PostgreSQL real (requieren dependencias)
  .env.example, requirements.txt, requirements-dev.txt
frontend/
  lib/config/api_config.dart     URL de la API (--dart-define=API_BASE_URL)
  lib/services/                  api_client.dart (HTTP/errores), app_services.dart (sesión)
  lib/models/                    meeting.dart, app_state.dart, history_data.dart
  lib/screens/, widgets/, theme/ pantallas originales, conectadas a la API
  test/                          pruebas de Flutter
  render-build.sh                compila Flutter Web en Render
```

## 3. Base de datos (migración `0001`)
`users`, `subjects` (6 materias semilla), `monitor_subjects` (máx. 3, solo monitores: trigger), `user_interests`,
`availability_slots` (weekday 0=lunes), `meetings` (DATE + TIME locales, `price_cop`, `status` scheduled|cancelled),
`registrations` (participantes; trigger: bloquea la reunión y rechaza cancelada/propia/sin cupos),
`payments` (pagos SIMULADOS, 1 por inscripción de pago, FK a `registrations`), `saved_meetings`, `email_verifications`
(HMAC del código, intentos, vencimiento). No se guardan: cupos disponibles, "completada", balances, estadísticas.
La migración ejecuta `alembic/sql/0001_initial_up.sql`; cada sentencia se separa con la línea `-- @@`.
**Cambios futuros del esquema = nueva migración `0002_...`**, no editar la 0001.

## 4. Funcionalidades y estado
Verificación: **E** = ejecutada en este entorno · **P** = escrita y preparada, NO ejecutada.

| Funcionalidad | Backend | Flutter | Verificación |
|---|---|---|---|
| Esquema, restricciones, triggers, cupos concurrentes, deshacer | sí | — | **E** (PG 16.15, 37 comprobaciones + concurrencia) |
| Hash de contraseñas, JWT, códigos, config, esquemas, recomendaciones, fechas, SQL de migración | sí | — | **E** (30 pruebas unitarias) |
| Modelos ORM coinciden con las tablas | sí | — | **E** revisión estática (0 discrepancias) |
| Registro, verificación de correo, reenvío, login | sí | sí | **P** |
| Búsqueda con filtros + orden "Recomendadas" | sí | sí | **P** |
| Detalle: guardar, unirse (cupos + pago simulado) | sí | sí | **P** |
| Nueva reunión (monitor puede poner precio) | sí | sí | **P** |
| Calendario, Historial (reuniones y pagos), Inicio, Perfil | sí | sí | **P** |
| Intereses, disponibilidad, materias del monitor (API) | sí | **sin pantalla** | **P** |
| Cancelar reunión (API) | sí | **sin botón** | **P** |

## 5. Endpoints que usa Flutter
| Método y ruta | Pantalla |
|---|---|
| `POST /auth/register`, `POST /auth/verify-email`, `POST /auth/resend-code`, `POST /auth/login` | Registro, Verificar correo, Login |
| `GET /meetings?q&subject&time_of_day&day&modality&price_min&price_max&sort&limit` | Buscar (sort: soonest, price, spots, recommended) |
| `POST /meetings`, `POST /meetings/{id}/join`, `PUT|DELETE /meetings/{id}/save` | Nueva reunión, Detalle, tarjetas |
| `GET /users/me/summary` | Inicio y Perfil |
| `GET /calendar?from&to` | Calendario |
| `GET /history/meetings?year&month&subject`, `GET /history/payments?year&month&subject&movement` | Historial |
Disponibles sin uso en Flutter aún: `GET /users/me`, `PUT /users/me/{interests,subjects,availability}`, `GET /meetings/{id}`, `POST /meetings/{id}/cancel`, `GET /subjects`, `GET /health`.
Errores: `{"code": "...", "message": "..."}` (422 validación, 401 sin sesión, 403, 404, 409, 429).
Documentación interactiva con el servidor en marcha: `http://localhost:8000/docs`.

## 6. Configuración local
```bash
# Backend
cd backend && python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
createdb study_with_me                      # o créala con pgAdmin
cp .env.example .env                        # completa DATABASE_URL y SECRET_KEY (ver comentarios)
alembic upgrade head
uvicorn app.main:app --reload               # http://localhost:8000/docs
# El código de verificación aparece en la consola del servidor: "[VERIFICACIÓN] Código para ...".

# Flutter (en tu proyecto, con tus carpetas android/ios/web)
flutter pub get
flutter run -d chrome                       # usa http://localhost:8000
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000   # celular físico (misma red)
# Emulador Android: usa http://10.0.2.2:8000 automáticamente.
```
**Pruebas**
```bash
cd backend
pytest tests/unit                                        # sin base de datos
./scripts/validate_schema.sh                             # ADMIN_DATABASE_URL=postgresql://usuario:clave@localhost/postgres
createdb swm_test && TEST_DATABASE_URL=postgresql://usuario:clave@localhost/swm_test pytest tests/integration   # VACÍA la base indicada
cd ../frontend && flutter analyze && flutter test
```

## 7. Render (nada publicado todavía)
`render.yaml` define: BD `study-with-me-db`; API `study-with-me-api` (build `pip install -r requirements.txt`, inicio
`alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT`, health `/health`, `SECRET_KEY` generada por Render,
`DATABASE_URL` desde la BD, `APP_ENV=production`); web `study-with-me-web` (estático, `frontend/render-build.sh`).
Pasos: (1) subir el repositorio a GitHub (sin `.env`); (2) Render → New → Blueprint; (3) tras el primer despliegue
copiar la URL de la API a `API_BASE_URL` de la web y la URL de la web a `CORS_ORIGINS` de la API; (4) redeploy de ambos;
(5) comprobar `https://<api>/health` y `/docs`. **Requiere tu autorización: los planes pueden tener costo y la BD gratuita vence.**
`FLUTTER_VERSION` puede ser una etiqueta como la de tu `flutter --version`; si el build falla, empieza por ahí.
Local y producción no se mezclan: la URL de producción solo entra por `--dart-define` / variable de Render.

## 8. Qué NO se verificó (límites del entorno de desarrollo)
PyPI está bloqueado (no se pudo instalar FastAPI, SQLAlchemy, psycopg ni Alembic) y no hay Flutter/Dart ni acceso a Render. Por eso **no se ejecutó**:
`alembic upgrade head`, el arranque de la app, las pruebas de integración, `flutter pub get/analyze/test`, la comunicación real Flutter↔API
y el despliegue. El código de esas partes pasó solo compilación de sintaxis (Python) y revisión manual (Dart). Es probable que aparezcan
errores menores al primer arranque: corre en este orden `alembic upgrade head` → `pytest tests/integration` → `flutter analyze` → `flutter test`.

## 9. Problemas conocidos y pendientes
- Archivo reemplazado: `verify_email_screen.dart`, `settings_screen.dart` y otros fueron editados; compara con tu copia si tienes cambios propios.
- Sin pantalla en Flutter para intereses, disponibilidad ni cancelar reunión (las recomendaciones usan intereses/disponibilidad/historial; sin esos datos ordenan por cercanía).
- Valoración 4.9 y Logros del Perfil: no existe la función; se muestra "—".
- "Olvidaste tu contraseña", editar perfil, cambiar contraseña, notificaciones, foto: sin implementar (no estaban definidos).
- La sesión no se guarda al cerrar la app (hay que iniciar sesión de nuevo); sin refresh token ni límite de intentos de login.
- Correo real: configurar `SMTP_*` (hoy el código solo sale en el log; quitar ese log temporal en producción cuando haya SMTP).
- Pagos simulados: no hay cobro ni reembolso al cancelar.
- Zona horaria: reuniones en hora local (`APP_TIMEZONE`); la BD no guarda zona para fecha/hora de la reunión.
- Render gratis: el servicio duerme; la primera petición tarda (timeout de Flutter: 60 s).

## 10. Próximos pasos exactos
1. Ejecutar la secuencia de la sección 8 y corregir lo que falle.
2. Probar a mano: registro → código en consola → verificar → crear reunión → unirse con otra cuenta → Calendario/Historial.
3. Con aprobación: desplegar con el Blueprint y probar `/health`.
4. Después: pantallas de intereses/disponibilidad (usar `PUT /users/me/...`), SMTP, persistir sesión.
