import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meeting.dart';
import 'api_client.dart';

// ============================================================
// SERVICIOS COMPARTIDOS (sesión + acceso a la API)
// Una sola instancia para toda la app. Guarda quién inició sesión
// y avisa (dataVersion) cuando cambian datos que otras pantallas
// muestran: calendario, historial y perfil.
// ============================================================

/// Una franja semanal en la que la persona puede estudiar (0 = lunes ... 6 = domingo).
class AvailabilitySlot {
  final int weekday;
  final TimeOfDay start;
  final TimeOfDay end;

  const AvailabilitySlot(
      {required this.weekday, required this.start, required this.end});

  factory AvailabilitySlot.fromJson(Map<String, dynamic> j) => AvailabilitySlot(
        weekday: (j['weekday'] as num).toInt(),
        start: parseApiTime(j['start_time'] as String),
        end: parseApiTime(j['end_time'] as String),
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_time': formatApiTime(start),
        'end_time': formatApiTime(end),
      };

  bool sameAs(AvailabilitySlot o) =>
      weekday == o.weekday && start == o.start && end == o.end;
}

/// Datos de la persona que inició sesión (GET /users/me).
class UserProfile {
  final String id;
  final String fullName;
  final String username; // sin '@'
  final String email;
  final String role; // 'student' | 'monitor'
  final List<String> subjects; // materias que domina (monitor)
  final List<String> interests; // materias que quiere aprender
  final List<AvailabilitySlot> availability; // franjas en las que puede estudiar

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    this.subjects = const [],
    this.interests = const [],
    this.availability = const [],
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
        availability: [
          for (final s in (j['availability'] as List? ?? const []))
            AvailabilitySlot.fromJson(s as Map<String, dynamic>),
        ],
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

  // ---------- Contraseña olvidada ----------

  /// Pide un código para restablecer la contraseña. El servidor responde lo mismo
  /// exista o no el correo.
  Future<void> forgotPassword(String email) async {
    await api.post('/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    await api.post('/auth/reset-password',
        body: {'email': email, 'code': code, 'new_password': newPassword});
  }

  // ---------- Perfil (requieren sesión) ----------

  void _setUser(dynamic data) {
    user = UserProfile.fromJson(data as Map<String, dynamic>);
    notifyDataChanged();
  }

  Future<void> updateProfile(
      {required String fullName, required String username}) async {
    _setUser(await api
        .put('/users/me', body: {'full_name': fullName, 'username': username}));
  }

  Future<void> changePassword(String current, String next) async {
    await api.post('/users/me/password',
        body: {'current_password': current, 'new_password': next});
  }

  /// Materias que domina (solo monitores, de 1 a 3).
  Future<void> saveSubjects(List<String> names) async =>
      _setUser(await api.put('/users/me/subjects', body: {'subjects': names}));

  /// Materias que le interesa aprender (alimentan las recomendaciones).
  Future<void> saveInterests(List<String> names) async =>
      _setUser(await api.put('/users/me/interests', body: {'subjects': names}));

  Future<void> saveAvailability(List<AvailabilitySlot> slots) async =>
      _setUser(await api.put('/users/me/availability',
          body: {'slots': [for (final s in slots) s.toJson()]}));

  void _startSession(Map<String, dynamic> data) {
    api.token = data['access_token'] as String;
    user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    _saveToken(api.token!);
    notifyDataChanged();
  }

  void logout() {
    api.token = null;
    user = null;
    _clearToken();
  }

  // ---------- Sesión persistente ----------
  // Solo se guarda el token (nunca la contraseña). Al abrir la app se valida
  // con GET /users/me: si venció o la cuenta fue suspendida, se descarta.
  static const _tokenKey = 'swm_token';

  Future<void> _saveToken(String token) async {
    try {
      (await SharedPreferences.getInstance()).setString(_tokenKey, token);
    } catch (_) {} // si el almacenamiento falla, la sesión sigue en memoria
  }

  Future<void> _clearToken() async {
    try {
      (await SharedPreferences.getInstance()).remove(_tokenKey);
    } catch (_) {}
  }

  /// Intenta retomar la sesión guardada. Devuelve true si el servidor la acepta.
  Future<bool> restoreSession() async {
    try {
      final token = (await SharedPreferences.getInstance()).getString(_tokenKey);
      if (token == null) return false;
      api.token = token;
      _setUser(await api.get('/users/me'));
      return true;
    } on ApiException catch (e) {
      api.token = null;
      user = null;
      // 401/403: token vencido o cuenta suspendida -> se borra. Otros errores
      // (servidor dormido, 5xx) conservan el token para el próximo intento.
      if (e.status == 401 || e.status == 403) await _clearToken();
      return false;
    } catch (_) {
      api.token = null;
      user = null;
      return false;
    }
  }
}