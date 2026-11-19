import 'package:flutter/foundation.dart';

// ============================================================
// DIRECCIÓN DE LA API
// Se puede cambiar al compilar, sin tocar el código:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
//   flutter build web --dart-define=API_BASE_URL=https://tu-api.onrender.com
// Por defecto:
//   - Web / escritorio / iOS simulador -> http://localhost:8000
//   - Emulador de Android              -> http://10.0.2.2:8000
//     (en el emulador "localhost" es el propio teléfono, no tu computador)
// ============================================================
class ApiConfig {
  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv.replaceAll(RegExp(r'/+$'), '');
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Render (plan gratis) duerme el servicio y tarda en despertar: damos margen.
  static const Duration timeout = Duration(seconds: 60);
}
