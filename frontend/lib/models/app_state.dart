import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import 'meeting.dart';

// ============================================================
// ESTADO COMPARTIDO DE LA APP
// Aquí viven las reuniones, la búsqueda y los filtros.
// Los datos vienen de la API (FastAPI + PostgreSQL); la búsqueda y los filtros
// se calculan en el servidor y aquí solo se guarda el resultado.
// Todas las pantallas (Inicio, Buscar, ...) leen y cambian este objeto,
// y cuando algo cambia se llama notifyListeners() para redibujarlas.
// ============================================================

/// Filtros avanzados de la búsqueda (los del panel "Filtrar reuniones").
class SearchFilters {
  String? subject; // null = todas las materias
  String? timeOfDay; // 'Mañana' / 'Tarde' / 'Noche' o null
  DateTime? day; // día específico o null
  String modality; // 'Todas' / 'Presencial' / 'Virtual'
  String price; // 'Todos' / 'Gratis' / 'Hasta $15k' / 'Más de $15k'

  SearchFilters({
    this.subject,
    this.timeOfDay,
    this.day,
    this.modality = 'Todas',
    this.price = 'Todos',
  });

  SearchFilters copy() => SearchFilters(
        subject: subject,
        timeOfDay: timeOfDay,
        day: day,
        modality: modality,
        price: price,
      );

  /// ¿Hay algún filtro del panel activo? (para mostrar el puntito amarillo)
  bool get hasAdvanced =>
      timeOfDay != null ||
      day != null ||
      modality != 'Todas' ||
      price != 'Todos' ||
      subject != null;
}

/// Una materia del carrusel de Inicio con su número de reuniones próximas.
class SubjectCount {
  final String name;
  final int upcoming;
  const SubjectCount(this.name, this.upcoming);
}

/// Cifras de Inicio y Perfil (GET /users/me/summary).
class Summary {
  final int sessionsCompleted;
  final double hoursCompleted;
  final int weekScheduled;
  final double weekHours;
  final int weekCompleted;
  final List<SubjectCount> subjects;
  final Meeting? nextMeeting;

  const Summary({
    required this.sessionsCompleted,
    required this.hoursCompleted,
    required this.weekScheduled,
    required this.weekHours,
    required this.weekCompleted,
    required this.subjects,
    required this.nextMeeting,
  });

  factory Summary.fromJson(Map<String, dynamic> j) {
    final week = j['week'] as Map<String, dynamic>;
    final next = j['next_meeting'];
    return Summary(
      sessionsCompleted: (j['sessions_completed'] as num).toInt(),
      hoursCompleted: (j['hours_completed'] as num).toDouble(),
      weekScheduled: (week['scheduled'] as num).toInt(),
      weekHours: (week['hours'] as num).toDouble(),
      weekCompleted: (week['completed'] as num).toInt(),
      subjects: [
        for (final s in j['subjects'] as List)
          SubjectCount((s as Map<String, dynamic>)['name'] as String,
              (s['upcoming'] as num).toInt()),
      ],
      nextMeeting:
          next == null ? null : Meeting.fromJson(next as Map<String, dynamic>),
    );
  }
}

class AppState extends ChangeNotifier {
  final AppServices services;

  AppState({AppServices? services}) : services = services ?? AppServices.instance;

  static const subjects = [
    'Cálculo',
    'Programación',
    'Física',
    'Inglés',
    'Bases de datos',
    'Matemáticas',
  ];
  static const sortOptions = [
    'Más próximas',
    'Menor precio',
    'Más cupos',
    'Recomendadas',
  ];
  static const _sortKeys = {
    'Más próximas': 'soonest',
    'Menor precio': 'price',
    'Más cupos': 'spots',
    'Recomendadas': 'recommended',
  };

  int tab = 0; // pestaña actual de la barra inferior
  String query = ''; // texto del buscador
  String sort = 'Más próximas';
  SearchFilters filters = SearchFilters();
  List<Meeting> meetings = []; // resultado de la última búsqueda
  Summary? summary; // cifras de Inicio/Perfil

  bool loading = false; // cargando la lista de reuniones
  String? error; // último error al cargar/actuar (null = sin error)

  Timer? _debounce;
  int _requestId = 0; // para ignorar respuestas viejas

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  ApiClient get _api => services.api;

  // ---------- Carga de datos ----------

  /// Parámetros que se envían a GET /meetings según búsqueda, filtros y orden.
  Map<String, String> get queryParams {
    final p = <String, String>{'sort': _sortKeys[sort] ?? 'soonest', 'limit': '200'};
    final text = query.trim();
    if (text.isNotEmpty) p['q'] = text;
    if (filters.subject != null) p['subject'] = filters.subject!;
    if (filters.timeOfDay != null) p['time_of_day'] = filters.timeOfDay!;
    if (filters.day != null) p['day'] = formatApiDate(filters.day!);
    if (filters.modality != 'Todas') p['modality'] = filters.modality;
    switch (filters.price) {
      case 'Gratis':
        p['price_max'] = '0';
        break;
      case 'Hasta \$15k':
        p['price_max'] = '15000';
        break;
      case 'Más de \$15k':
        p['price_min'] = '15001';
        break;
    }
    return p;
  }

  /// Vuelve a pedir la lista de reuniones al servidor.
  Future<void> refresh() async {
    final id = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/meetings', query: queryParams) as List;
      if (id != _requestId) return; // llegó una respuesta más nueva
      meetings = [
        for (final j in data) Meeting.fromJson(j as Map<String, dynamic>),
      ];
    } on ApiException catch (e) {
      if (id != _requestId) return;
      error = e.message;
    } catch (_) {
      if (id != _requestId) return;
      error = 'No se pudieron cargar las reuniones.';
    }
    loading = false;
    notifyListeners();
  }

  /// Pide al servidor las cifras de Inicio y Perfil.
  Future<void> loadSummary() async {
    try {
      final data = await _api.get('/users/me/summary') as Map<String, dynamic>;
      summary = Summary.fromJson(data);
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  /// Recarga todo lo que depende de las reuniones del usuario.
  Future<void> reloadAll() async {
    services.notifyDataChanged(); // Calendario, Historial y Perfil se recargan
    await Future.wait([refresh(), loadSummary()]);
  }

  // ---------- Navegación ----------

  void goToTab(int index) {
    tab = index;
    notifyListeners();
  }

  /// Desde Inicio: tocar una materia abre Buscar ya filtrado.
  void openSearchWithSubject(String subject) {
    filters = SearchFilters(subject: subject);
    query = '';
    tab = 1;
    notifyListeners();
    refresh();
  }

  // ---------- Búsqueda ----------

  void setQuery(String value) {
    query = value;
    notifyListeners();
    // Esperamos a que la persona termine de escribir antes de preguntar al servidor.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  void setSubject(String? subject) {
    filters.subject = subject;
    notifyListeners();
    refresh();
  }

  void setFilters(SearchFilters newFilters) {
    filters = newFilters;
    notifyListeners();
    refresh();
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
    refresh();
  }

  /// Reuniones de la búsqueda actual, ya filtradas y ordenadas por el servidor.
  List<Meeting> get results => meetings;

  // ---------- Acciones sobre reuniones ----------
  // Todas devuelven null si salió bien, o el mensaje de error para mostrarlo.

  Future<String?> toggleSaved(Meeting m) async {
    try {
      final data = m.saved
          ? await _api.delete('/meetings/${m.id}/save')
          : await _api.put('/meetings/${m.id}/save');
      m.updateFrom(Meeting.fromJson(data as Map<String, dynamic>));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> join(Meeting m) async {
    if (m.joined || m.spots == 0) return null;
    try {
      final data = await _api.post('/meetings/${m.id}/join');
      m.updateFrom(Meeting.fromJson(data as Map<String, dynamic>));
      await reloadAll();
      return null;
    } on ApiException catch (e) {
      // Por ejemplo "sin cupos": refrescamos para mostrar los cupos reales.
      refresh();
      return e.message;
    }
  }

  /// Publica una reunión nueva. [price] solo lo aceptan los monitores.
  Future<String?> createMeeting({
    required String title,
    required String subject,
    required String description,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    required bool isVirtual,
    required String location,
    required int capacity,
    int price = 0,
  }) async {
    try {
      await _api.post('/meetings', body: {
        'title': title,
        'subject': subject,
        'description': description,
        'date': formatApiDate(date),
        'start_time': formatApiTime(start),
        'end_time': formatApiTime(end),
        'is_virtual': isVirtual,
        'location': location,
        'capacity': capacity,
        'price': price,
      });
      await reloadAll();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Edita una reunión ya publicada (solo quien la creó). Devuelve el mensaje de
  /// error del servidor o null si salió bien. El servidor impide, por ejemplo,
  /// cambiar materia o precio cuando ya hay personas inscritas.
  Future<String?> updateMeeting(
    Meeting m, {
    required String title,
    required String subject,
    required String description,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    required bool isVirtual,
    required String location,
    required int capacity,
    int price = 0,
  }) async {
    try {
      await _api.put('/meetings/${m.id}', body: {
        'title': title,
        'subject': subject,
        'description': description,
        'date': formatApiDate(date),
        'start_time': formatApiTime(start),
        'end_time': formatApiTime(end),
        'is_virtual': isVirtual,
        'location': location,
        'capacity': capacity,
        'price': price,
      });
      await reloadAll();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Cancela una reunión que creaste. Devuelve el mensaje de error o null si salió bien.
  Future<String?> cancelMeeting(Meeting m) async {
    try {
      await _api.post('/meetings/${m.id}/cancel');
      await reloadAll();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // ---------- Datos para Inicio ----------

  /// Próxima sesión: la primera en la que participo; si no hay, la más cercana de la lista.
  Meeting? get nextMeeting {
    final mine = summary?.nextMeeting;
    if (mine != null) return mine;
    if (meetings.isEmpty) return null;
    final sorted = [...meetings]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return sorted.first;
  }

  int get joinedCount => meetings.where((m) => m.joined).length;
}