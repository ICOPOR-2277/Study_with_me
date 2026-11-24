# Study With Me

Aplicación web para organizar y encontrar reuniones de estudio entre estudiantes. El proyecto está compuesto por una interfaz desarrollada en Flutter, una API REST construida con FastAPI y una base de datos PostgreSQL.

> **Estado de la documentación:** este README reúne las secciones 1 a 7 del estado técnico del proyecto. Distingue las funcionalidades implementadas de aquellas que están preparadas pero todavía requieren pruebas de ejecución o integración.

---

## 1. Arquitectura del proyecto

La aplicación utiliza una arquitectura cliente-servidor de tres capas:

```text
Flutter (frontend/)
       |
       | HTTP / JSON + JWT
       v
FastAPI (backend/app/)
       |
       | SQLAlchemy 2.0
       v
PostgreSQL 16
```

Flutter se comunica exclusivamente con la API mediante solicitudes HTTP. **El frontend nunca se conecta directamente a PostgreSQL**. La API valida las solicitudes, aplica las reglas de negocio y consulta o modifica los datos a través de SQLAlchemy.

En el despliegue se contemplan tres servicios independientes en Render:

1. **PostgreSQL:** almacena usuarios, materias, reuniones, inscripciones y demás información del sistema.
2. **FastAPI:** expone los endpoints, valida las solicitudes, administra la autenticación y accede a la base de datos.
3. **Flutter Web:** entrega la aplicación web compilada como sitio estático.

### Tecnologías principales

| Capa | Tecnología | Uso |
|---|---|---|
| Frontend | Flutter / Dart 3 o superior | Interfaz de usuario multiplataforma. |
| Diseño de interfaz | Material 3 | Componentes y estilos visuales. |
| Estado | `ChangeNotifier` | Administración y notificación de cambios de estado. |
| Comunicación | Paquete `http` | Consumo de la API REST. |
| Backend | Python 3.12+, FastAPI | Servicios y endpoints HTTP. |
| Validación | Pydantic v2 | Validación de datos de entrada y salida. |
| ORM | SQLAlchemy 2.0 | Acceso a la base de datos. |
| Driver PostgreSQL | psycopg 3 | Conexión entre Python y PostgreSQL. |
| Migraciones | Alembic | Creación y evolución del esquema de base de datos. |
| Autenticación | PyJWT | Emisión y validación de tokens JWT. |
| Base de datos | PostgreSQL 16 | Persistencia de la información. |

### Seguridad y sesiones

- Las contraseñas se procesan con `hashlib.scrypt`, utilizando los parámetros `N=2^15`, `r=8` y `p=1`.
- Los parámetros necesarios para verificar cada hash se conservan junto con el hash de la contraseña.
- La autenticación utiliza tokens JWT firmados con HS256.
- La duración predeterminada de la sesión es de 12 horas.
- La implementación descrita no utiliza refresh tokens.
- Los códigos de verificación de correo se almacenan mediante HMAC, junto con información de intentos y vencimiento; no se guarda el código en texto plano.

---

## 2. Estructura del repositorio

La estructura principal del proyecto es la siguiente:

```text
Study_with_me/
├── render.yaml                  # Blueprint de Render: PostgreSQL, API y web
├── README.md                    # Documentación principal
│
├── backend/
│   ├── app/
│   │   ├── main.py              # Crea la aplicación FastAPI y configura CORS
│   │   ├── core/
│   │   │   ├── config.py        # Configuración y variables de entorno
│   │   │   ├── security.py      # Hash, JWT y códigos de verificación
│   │   │   ├── deps.py          # Dependencias de autenticación y contexto
│   │   │   ├── errors.py        # Manejo de errores
│   │   │   └── timeutil.py      # Utilidades de fecha y hora
│   │   ├── db/
│   │   │   ├── base.py          # Base declarativa de SQLAlchemy
│   │   │   └── session.py       # Motor y sesiones de base de datos
│   │   ├── models/              # Modelos ORM
│   │   ├── schemas/             # Contratos y esquemas Pydantic
│   │   ├── services/            # Lógica de negocio
│   │   └── routers/             # Rutas de la API
│   ├── alembic/
│   │   ├── env.py               # Configuración de migraciones
│   │   ├── versions/            # Historial de migraciones
│   │   └── sql/                 # SQL utilizado por las migraciones
│   ├── scripts/
│   │   ├── validate_schema.sh   # Validación del esquema
│   │   └── schema_checks.sql    # Comprobaciones SQL
│   ├── tests/
│   │   ├── unit/                # Pruebas unitarias
│   │   └── integration/         # Pruebas de integración con PostgreSQL
│   ├── .env.example             # Plantilla de configuración local
│   ├── requirements.txt        # Dependencias de ejecución
│   ├── requirements-dev.txt    # Dependencias de desarrollo y pruebas
│   └── alembic.ini              # Configuración principal de Alembic
│
└── frontend/
    ├── lib/
    │   ├── config/              # Configuración de la URL de la API
    │   ├── services/            # Cliente HTTP y servicios de aplicación
    │   ├── models/              # Modelos utilizados por Flutter
    │   ├── screens/              # Pantallas
    │   ├── widgets/              # Componentes reutilizables
    │   └── theme/                # Tema visual
    ├── test/                    # Pruebas de Flutter
    ├── web/                     # Archivos de la plataforma web
    ├── pubspec.yaml             # Dependencias de Flutter
    ├── pubspec.lock             # Versiones resueltas de dependencias
    └── render-build.sh          # Compilación de Flutter Web para Render
```

Los nombres o subdirectorios internos pueden variar si se reorganiza el código. Para trabajar sobre el proyecto, se debe tomar como referencia la estructura real del repositorio.

### Componentes principales del backend

- **`routers/`:** define los endpoints de autenticación, usuarios, materias, reuniones y reportes.
- **`services/`:** contiene la lógica de autenticación, usuarios, reuniones, informes, recomendaciones, materias y correo.
- **`models/`:** representa las entidades persistidas en PostgreSQL.
- **`schemas/`:** define los datos aceptados y devueltos por la API.
- **`core/`:** concentra configuración, seguridad, dependencias y utilidades comunes.

### Componentes principales del frontend

- **`api_config.dart`:** obtiene la URL de la API mediante `--dart-define=API_BASE_URL`.
- **`api_client.dart`:** centraliza las solicitudes HTTP y el tratamiento de errores.
- **`app_services.dart`:** concentra servicios relacionados con la sesión y el estado de la aplicación.
- **`screens/` y `widgets/`:** contienen las pantallas y componentes visuales.
- **`theme/`:** agrupa la configuración visual de la aplicación.

---

## 3. Base de datos y migraciones

El sistema utiliza **PostgreSQL 16**. El esquema inicial se crea mediante la migración `0001`, ejecutada por Alembic a partir del archivo SQL correspondiente.

### Tablas principales

| Tabla | Propósito |
|---|---|
| `users` | Cuentas y datos principales de los usuarios. |
| `subjects` | Catálogo de materias; la migración inicial incluye seis materias semilla. |
| `monitor_subjects` | Materias que puede ofrecer un monitor. El esquema limita la cantidad y aplica reglas para este tipo de usuario. |
| `user_interests` | Materias o áreas de interés de cada usuario. |
| `availability_slots` | Disponibilidad semanal. El día de la semana utiliza `0` para lunes. |
| `meetings` | Reuniones de estudio, con fecha, hora local, precio y estado. |
| `registrations` | Inscripciones de participantes a reuniones. |
| `payments` | Registros de pagos simulados asociados a inscripciones de pago. |
| `saved_meetings` | Reuniones guardadas por los usuarios. |
| `email_verifications` | Verificaciones de correo, incluyendo HMAC del código, intentos y vencimiento. |

### Reglas relevantes del esquema

- Las claves principales utilizan UUID.
- Se aplican restricciones `CHECK`, claves foráneas y triggers para proteger la integridad de los datos.
- Un monitor puede registrar como máximo tres materias en `monitor_subjects`.
- Los triggers de inscripciones controlan la disponibilidad de cupos y bloquean inscripciones inválidas, como unirse a una reunión cancelada, a una reunión propia o a una reunión sin cupos.
- Los pagos son **simulados**: el proyecto no procesa cobros reales ni reembolsos.
- Los cupos disponibles y las estadísticas derivadas no se almacenan como valores independientes cuando pueden calcularse a partir de los registros existentes.

### Migraciones

La migración inicial está identificada como `0001`. Su SQL se encuentra en `backend/alembic/sql/0001_initial_up.sql` y el archivo de reversión correspondiente en `backend/alembic/sql/0001_initial_down.sql`. El ejecutor separa las sentencias mediante la línea delimitadora `-- @@`.

**Regla para cambios futuros:** no se debe editar la migración `0001` después de haber sido utilizada en una base de datos compartida o desplegada. Cada cambio estructural debe agregarse mediante una nueva migración, por ejemplo:

```text
backend/alembic/versions/0002_descripcion_del_cambio.py
```

Para aplicar las migraciones pendientes:

```bash
alembic upgrade head
```

Para consultar la revisión aplicada:

```bash
alembic current
```

La cadena de conexión se configura mediante `DATABASE_URL` en el entorno del backend. La base de datos local y la de producción son independientes; ejecutar una migración local no modifica automáticamente la base de datos de Render.

---

## 4. Funcionalidades y estado de implementación

La siguiente tabla diferencia entre las partes verificadas en el entorno de desarrollo y las que están escritas o preparadas, pero todavía necesitan ejecución o pruebas integrales.

**Leyenda:**

- **E — Ejecutada/verificada:** existe evidencia de ejecución en el entorno indicado o de revisión estática especificada.
- **P — Preparada, pendiente de ejecución:** el código está desarrollado o preparado, pero la funcionalidad aún requiere pruebas de ejecución o integración.

| Funcionalidad | Backend | Flutter | Verificación / estado |
|---|---|---|---|
| Esquema, restricciones, triggers, control concurrente de cupos y reversión | Sí | — | **E:** PostgreSQL 16.15; 37 comprobaciones y prueba de concurrencia. |
| Hash de contraseñas, JWT, códigos, configuración, esquemas, recomendaciones, fechas y SQL de migración | Sí | — | **E:** 30 pruebas unitarias. |
| Correspondencia entre modelos ORM y tablas | Sí | — | **E:** revisión estática sin discrepancias detectadas. |
| Registro, verificación de correo, reenvío de código e inicio de sesión | Sí | Sí | **P:** falta completar las pruebas integrales. |
| Búsqueda de reuniones con filtros y orden recomendado | Sí | Sí | **P** |
| Detalle de reunión, guardar y unirse con control de cupos y pago simulado | Sí | Sí | **P** |
| Crear reunión y permitir que el monitor establezca un precio | Sí | Sí | **P** |
| Calendario, historial de reuniones y pagos, inicio y perfil | Sí | Sí | **P** |
| Intereses, disponibilidad y materias del monitor | Sí | Sin pantalla completa | **P** |
| Cancelación de reuniones | Sí | Sin botón | **P** |

El estado **P** no significa necesariamente que la funcionalidad esté ausente: indica que no debe considerarse completamente validada hasta ejecutar las pruebas correspondientes en un entorno integrado.

---

## 5. API REST: endpoints principales

Con el backend en ejecución, la documentación interactiva de FastAPI está disponible en:

```text
http://localhost:8000/docs
```

### Autenticación

| Método | Ruta | Uso |
|---|---|---|
| `POST` | `/auth/register` | Registrar una cuenta. |
| `POST` | `/auth/verify-email` | Verificar el correo mediante el código recibido. |
| `POST` | `/auth/resend-code` | Solicitar el reenvío del código de verificación. |
| `POST` | `/auth/login` | Iniciar sesión y obtener el token de autenticación. |

### Reuniones

| Método | Ruta | Uso |
|---|---|---|
| `GET` | `/meetings` | Buscar reuniones con filtros y opciones de ordenamiento. |
| `POST` | `/meetings` | Crear una reunión. |
| `GET` | `/meetings/{id}` | Consultar el detalle de una reunión. |
| `POST` | `/meetings/{id}/join` | Inscribirse a una reunión. |
| `PUT` / `DELETE` | `/meetings/{id}/save` | Guardar o quitar una reunión de guardadas. |
| `POST` | `/meetings/{id}/cancel` | Cancelar una reunión, según las reglas del backend. |

El endpoint `GET /meetings` acepta los siguientes parámetros de búsqueda documentados:

```text
q, subject, time_of_day, day, modality,
price_min, price_max, sort, limit
```

Los valores de ordenamiento contemplados son `soonest`, `price`, `spots` y `recommended`.

### Usuarios, materias y reportes

| Método | Ruta | Uso |
|---|---|---|
| `GET` | `/users/me` | Consultar el perfil del usuario autenticado. |
| `GET` | `/users/me/summary` | Obtener el resumen utilizado en Inicio y Perfil. |
| `PUT` | `/users/me/interests` | Actualizar intereses del usuario. |
| `PUT` | `/users/me/subjects` | Actualizar materias del monitor. |
| `PUT` | `/users/me/availability` | Actualizar disponibilidad. |
| `GET` | `/subjects` | Consultar las materias disponibles. |
| `GET` | `/calendar` | Consultar reuniones del calendario. |
| `GET` | `/history/meetings` | Consultar historial de reuniones. |
| `GET` | `/history/payments` | Consultar historial de pagos. |
| `GET` | `/health` | Comprobar el estado de la API. |

Parámetros de reportes documentados:

- `GET /calendar`: `from`, `to`.
- `GET /history/meetings`: `year`, `month`, `subject`.
- `GET /history/payments`: `year`, `month`, `subject`, `movement`.

### Formato general de errores

La API utiliza respuestas de error con una estructura común:

```json
{
  "code": "error_code",
  "message": "Descripción del problema"
}
```

Entre los códigos HTTP contemplados se encuentran:

| Código | Significado habitual |
|---|---|
| `401` | No existe una sesión válida o falta autenticación. |
| `403` | El usuario no tiene permiso para realizar la operación. |
| `404` | No se encontró el recurso solicitado. |
| `409` | Conflicto con el estado actual del recurso o de la operación. |
| `422` | Los datos enviados no superan la validación. |
| `429` | Se alcanzó un límite de solicitudes. |

La lista exacta de rutas, parámetros, esquemas y respuestas debe consultarse en `/docs`, que refleja la versión del backend que se esté ejecutando.

---

## 6. Instalación y ejecución local

### Requisitos previos

Instala las siguientes herramientas antes de iniciar:

- Python 3.12 o superior.
- PostgreSQL 16.
- Flutter y Dart compatibles con el proyecto (Dart 3 o superior).
- Git.
- Un editor de código, como Visual Studio Code.

Comprueba las instalaciones:

```bash
python --version
psql --version
flutter --version
dart --version
git --version
```

### 6.1. Obtener el proyecto

Clona el repositorio y entra en su carpeta:

```bash
git clone https://github.com/ICOPOR-2277/Study_with_me.git
cd Study_with_me
```

Si el repositorio o su rama principal cambian, utiliza la URL y la rama vigentes en GitHub.

### 6.2. Configurar el backend

Desde la raíz del repositorio, entra en `backend` y crea un entorno virtual:

```bash
cd backend
python -m venv .venv
```

Activa el entorno virtual.

**Windows (PowerShell):**

```powershell
.venv\Scripts\Activate.ps1
```

**Windows (CMD):**

```bat
.venv\Scripts\activate.bat
```

**Linux o macOS:**

```bash
source .venv/bin/activate
```

Instala las dependencias de desarrollo:

```bash
pip install -r requirements-dev.txt
```

Crea el archivo de configuración local a partir de la plantilla:

**Windows (PowerShell):**

```powershell
Copy-Item .env.example .env
```

**Linux o macOS:**

```bash
cp .env.example .env
```

Edita `backend/.env` y completa, como mínimo, las variables que la configuración del proyecto requiera para conectarse a PostgreSQL y firmar los tokens. La plantilla `backend/.env.example` contiene los nombres y comentarios de las variables esperadas.

Ejemplo ilustrativo de una URL de base de datos local:

```env
DATABASE_URL=postgresql+psycopg://usuario:clave@localhost:5432/study_with_me
SECRET_KEY=reemplazar_por_una_clave_local_segura
APP_ENV=development
APP_TIMEZONE=America/Bogota
```

> Los valores anteriores son ejemplos. Utiliza el usuario, la contraseña, el nombre de base de datos y las demás variables que correspondan a tu instalación. No subas el archivo `.env` a GitHub.

Crea una base de datos vacía llamada `study_with_me` desde pgAdmin o mediante PostgreSQL. Por ejemplo, con un usuario que tenga permiso para crear bases de datos:

```bash
createdb study_with_me
```

Aplica las migraciones desde la carpeta `backend`:

```bash
alembic upgrade head
```

Inicia la API:

```bash
uvicorn app.main:app --reload
```

La API estará disponible en:

```text
http://localhost:8000
```

La documentación interactiva estará en:

```text
http://localhost:8000/docs
```

El endpoint de salud es:

```text
http://localhost:8000/health
```

### 6.3. Configurar y ejecutar Flutter

Abre una segunda terminal y, desde la raíz del repositorio, entra en `frontend`:

```bash
cd frontend
flutter pub get
```

Para ejecutar la aplicación en Chrome con el valor de API local predeterminado configurado en el proyecto:

```bash
flutter run -d chrome
```

Para especificar expresamente la URL de la API:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

En un teléfono físico conectado a la misma red Wi-Fi que el equipo donde se ejecuta FastAPI, utiliza la dirección IP local del equipo, por ejemplo:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

Sustituye `192.168.1.20` por la dirección IP local real del equipo. El servidor debe aceptar conexiones desde la red local y el firewall debe permitir el puerto utilizado.

Para un emulador Android, el host del equipo normalmente se alcanza mediante `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

La configuración central de la URL se encuentra en `frontend/lib/config/api_config.dart`. La aplicación debe recibir la dirección correcta para el entorno en el que se esté ejecutando.

### 6.4. Ejecutar las pruebas

**Pruebas unitarias del backend** — no requieren una base de datos de integración:

```bash
cd backend
pytest tests/unit
```

**Validación del esquema:**

```bash
./scripts/validate_schema.sh
```

El script utiliza `ADMIN_DATABASE_URL` para conectarse a una base de datos administrativa. Configura esa variable con una conexión válida antes de ejecutarlo. Ejemplo ilustrativo:

```text
postgresql://usuario:clave@localhost/postgres
```

**Pruebas de integración:** requieren PostgreSQL y una base de datos de pruebas dedicada. El conjunto indicado puede vaciar la base especificada, por lo que no se debe apuntar a una base con información que se quiera conservar.

```bash
createdb swm_test
TEST_DATABASE_URL=postgresql://usuario:clave@localhost/swm_test pytest tests/integration
```

En PowerShell, configura la variable de entorno para la sesión antes de ejecutar pytest:

```powershell
$env:TEST_DATABASE_URL="postgresql://usuario:clave@localhost/swm_test"
pytest tests/integration
```

**Análisis y pruebas de Flutter:**

```bash
cd frontend
flutter analyze
flutter test
```

---

## 7. Despliegue en Render

El archivo `render.yaml`, ubicado en la raíz del repositorio, define un Blueprint con tres servicios independientes:

| Servicio | Nombre en Render | Configuración |
|---|---|---|
| Base de datos | `study-with-me-db` | PostgreSQL; base `study_with_me`. |
| API | `study-with-me-api` | Web Service con Python, FastAPI y Uvicorn. |
| Frontend | `study-with-me-web` | Static Site compilado desde Flutter Web. |

### 7.1. Configuración declarada en el Blueprint

**API:**

- Directorio raíz: `backend`.
- Instalación: `pip install -r requirements.txt`.
- Inicio: `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT`.
- Comprobación de salud: `/health`.
- `DATABASE_URL`: se obtiene de la conexión interna de la base de datos creada por el Blueprint.
- `SECRET_KEY`: se genera desde Render mediante `generateValue: true`.
- `APP_ENV`: `production`.
- `APP_TIMEZONE`: `America/Bogota`.

**Frontend:**

- Directorio raíz: `frontend`.
- Script de compilación: `./render-build.sh`.
- Directorio publicado: `build/web`.
- Versión de Flutter: se configura mediante `FLUTTER_VERSION`.
- URL del backend: se entrega durante la compilación con `API_BASE_URL`.

El script `frontend/render-build.sh` descarga Flutter cuando no está disponible en el entorno, instala las dependencias con `flutter pub get` y compila Flutter Web con `--dart-define=API_BASE_URL=...`.

### 7.2. Variables de entorno

Las variables se configuran en el servicio correspondiente, desde **Environment** en el Dashboard de Render. No deben almacenarse secretos en el repositorio.

| Servicio | Variable | Valor o propósito |
|---|---|---|
| API | `DATABASE_URL` | Conexión PostgreSQL proporcionada por Render. |
| API | `SECRET_KEY` | Clave de firma JWT; debe ser secreta. |
| API | `APP_ENV` | `production`. |
| API | `APP_TIMEZONE` | `America/Bogota`. |
| API | `CORS_ORIGINS` | URL pública del frontend, una vez que Render la asigne. |
| Web | `API_BASE_URL` | URL pública del servicio FastAPI. |
| Web | `FLUTTER_VERSION` | Rama o etiqueta de Flutter que usará el script de compilación. |

#### Configuración de CORS y URL de la API

Las URL no deben inventarse ni copiarse de ejemplos. Render asigna las direcciones al crear los servicios.

1. Copia la URL pública de `study-with-me-api` y configúrala como `API_BASE_URL` en `study-with-me-web`.
2. Copia la URL pública de `study-with-me-web` y configúrala como `CORS_ORIGINS` en `study-with-me-api`.
3. Guarda los cambios y vuelve a desplegar los servicios para que utilicen las variables actualizadas.

`API_BASE_URL` debe contener la URL de la API sin una barra final, de acuerdo con el comentario del script de compilación.

### 7.3. Envío de correos con Resend

La configuración local del proyecto contemplaba variables SMTP. Para el despliegue en Render se está considerando utilizar **Resend mediante su API HTTPS**, en lugar de depender de SMTP.

La integración debe contemplar, como mínimo, estas variables en el servicio de API:

| Variable | Propósito |
|---|---|
| `RESEND_API_KEY` | Clave privada para autenticar las solicitudes a Resend. |
| `RESEND_FROM` | Dirección remitente verificada que utilizará el sistema. |

**Estado:** la configuración de estas variables en Render no implementa por sí sola el envío. El backend debe incorporar o adaptar el servicio de correo para realizar las solicitudes a Resend y manejar sus respuestas y errores. Hasta completar y probar ese cambio, no se debe considerar verificado el envío real de correos en producción.

No incluyas `RESEND_API_KEY`, contraseñas SMTP, claves JWT ni credenciales de base de datos en GitHub, en este README o en capturas públicas. Configúralas como variables secretas en Render y utiliza valores de ejemplo en `.env.example`.

### 7.4. Estado actual del despliegue

Durante la configuración inicial del Blueprint:

- Render creó el recurso PostgreSQL `study-with-me-db`.
- Render creó el servicio web `study-with-me-api`.
- El primer despliegue de `study-with-me-web` falló durante la compilación porque no estaba definida la variable `API_BASE_URL`.

El registro de compilación mostró el mensaje:

```text
API_BASE_URL: Define API_BASE_URL con la URL de la API
```

Para continuar, configura `API_BASE_URL` en el entorno del servicio estático con la URL pública real de `study-with-me-api` y vuelve a ejecutar el despliegue. Cuando el frontend esté disponible, configura `CORS_ORIGINS` en la API con la URL pública real de la web.

Una vez terminados los despliegues, verifica al menos:

```text
https://<URL-DE-LA-API>/health
https://<URL-DE-LA-API>/docs
```

Después realiza pruebas funcionales desde la web, incluyendo registro, verificación de correo, inicio de sesión y operaciones principales de reuniones.

### 7.5. Actualizaciones posteriores

Cuando el repositorio esté conectado a Render, los cambios enviados a la rama configurada pueden iniciar nuevos despliegues automáticos, según la configuración de cada servicio.

Flujo habitual desde la raíz del proyecto:

```bash
git add .
git commit -m "Describe los cambios realizados"
git push origin main
```

Antes de subir cambios:

- Comprueba que `.env` y otros archivos con secretos estén excluidos mediante `.gitignore`.
- Ejecuta las pruebas relevantes.
- Añade una nueva migración de Alembic cuando cambie el esquema de PostgreSQL.
- Revisa las migraciones antes de aplicarlas a la base de producción.

### 7.6. Consideraciones de planes y datos

Revisa los planes, límites, suspensión por inactividad, vencimiento y posibles costos directamente en Render antes de confirmar o modificar servicios. La disponibilidad y las condiciones de los planes pueden cambiar.

La base de datos local y la base de datos de Render son independientes. Crear la base en Render no copia automáticamente los datos de desarrollo. Si se requiere transferir información, debe prepararse un procedimiento de exportación e importación controlado y con respaldo previo.

---