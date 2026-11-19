import 'package:flutter/foundation.dart';

import '../models/meeting.dart';
import 'api_client.dart';

// ============================================================
// SERVICIOS COMPARTIDOS (sesión + acceso a la API)
// Una sola instancia para toda la app. Guarda quién inició sesión
// y avisa (dataVersion) cuando cambian datos que otras pantallas
// muestran: calendario, historial y perfil.
// ============================================================

/// Datos de la persona que inició sesión (GET /users/me).
class UserProfile {
  final String id;
  final String fullName;
  final String username; // sin '@'
  final String email;
  final String role; // 'student' | 'monitor'
  final List<String> subjects; // materias que domina (monitor)
  final List<String> interests; // materias que quiere aprender

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    this.subjects = const [],
    this.interests = const [],
  });

  bool get isMonitor => role == 'monitor';
  String get firstName => fullName.trim().split(' ').first;
  String get initials => initialsOf(fullName);

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        subjects: List<String>.from(j['subjects'] as List? ?? const []),
        interests: List<String>.from(j['interests'] as List? ?? const []),
      );
}

class AppServices {
  AppServices._();
  static final AppServices instance = AppServices._();

  /// Se puede reemplazar en pruebas por un ApiClient con http falso.
  ApiClient api = ApiClient();
  UserProfile? user;

  /// Sube cada vez que se crea/une/cancela una reunión.
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
  void notifyDataChanged() => dataVersion.value++;

  bool get isLoggedIn => user != null && api.token != null;

  // ---------- Autenticación ----------

  /// Crea la cuenta. El servidor envía (por ahora, escribe en su log) un código.
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String role,
    required List<String> subjects,
  }) async {
    await api.post('/auth/register', body: {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      'subjects': subjects,
    });
  }

  Future<void> verifyEmail(String email, String code) async {
    final data = await api.post('/auth/verify-email',
        body: {'email': email, 'code': code}) as Map<String, dynamic>;
    _startSession(data);
  }

  Future<void> resendCode(String email) async {
    await api.post('/auth/resend-code', body: {'email': email});
  }

  Future<void> login(String email, String password) async {
    final data = await api.post('/auth/login',
        body: {'email': email, 'password': password}) as Map<String, dynamic>;
    _startSession(data);
  }

  void _startSession(Map<String, dynamic> data) {
    api.token = data['access_token'] as String;
    user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    notifyDataChanged();
  }

  void logout() {
    api.token = null;
    user = null;
  }
}
