#!/usr/bin/env bash
# Compila Flutter Web en Render (servicio estático). Render no trae Flutter: se descarga aquí.
# Variables: FLUTTER_VERSION (rama/etiqueta de Flutter, ver "flutter --version" en tu equipo)
#            API_BASE_URL   (URL pública de la API en Render, sin "/" final)
set -euo pipefail
cd "$(dirname "$0")"

: "${API_BASE_URL:?Define API_BASE_URL con la URL de la API}"
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"

if [ ! -d "$HOME/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"

flutter config --no-analytics >/dev/null
flutter pub get
# Si el proyecto aún no tiene la carpeta web/, se crea (no sobrescribe archivos existentes).
[ -d web ] || flutter create . --platforms=web
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
