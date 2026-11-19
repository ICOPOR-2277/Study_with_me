import os

# Variables mínimas para importar la app en pruebas (valores de prueba, no reales).
os.environ.setdefault("SECRET_KEY", "test-secret-key-test-secret-key-0123456789")
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")
os.environ.setdefault("APP_ENV", "development")
