"""Punto de entrada de la API: uvicorn app.main:app"""
from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.routers import auth, meetings, reports, subjects, users

logging.basicConfig(level=logging.INFO)

# En desarrollo se permite cualquier puerto de localhost (flutter run -d chrome usa uno aleatorio).
DEV_ORIGIN_REGEX = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app = FastAPI(title="Study With Me API", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=None if settings.is_production else DEV_ORIGIN_REGEX,
        allow_methods=["*"],
        allow_headers=["Authorization", "Content-Type"],
    )

    @app.exception_handler(AppError)
    async def app_error_handler(_: Request, exc: AppError):
        return JSONResponse(status_code=exc.status_code, content={"code": exc.code, "message": exc.message})

    @app.exception_handler(RequestValidationError)
    async def validation_handler(_: Request, exc: RequestValidationError):
        first = exc.errors()[0] if exc.errors() else {}
        field = ".".join(str(p) for p in first.get("loc", []) if p != "body")
        msg = str(first.get("msg", "Datos no válidos")).removeprefix("Value error, ")
        return JSONResponse(status_code=422, content={"code": "validation_error", "message": f"{field}: {msg}" if field else msg})

    @app.get("/health", tags=["health"])
    def health():
        return {"status": "ok"}

    for module in (auth, users, subjects, meetings, reports):
        app.include_router(module.router)
    return app


app = create_app()
