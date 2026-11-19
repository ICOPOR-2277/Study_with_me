import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_with_me/models/app_state.dart';
import 'package:study_with_me/models/meeting.dart';
import 'package:study_with_me/services/app_services.dart';

import 'test_helpers.dart';

void main() {
  test('refresh pide /meetings con los filtros y llena la lista', () async {
    final seen = installFakeApi((r) async => jsonResponse([
          meetingJson(),
          meetingJson(id: '33333333-3333-3333-3333-333333333333', title: 'Python', subject: 'Programación', price: 0),
        ]));
    final state = AppState();
    state.query = 'der';
    state.filters = SearchFilters(
        subject: 'Cálculo', timeOfDay: 'Mañana', modality: 'Presencial', price: 'Hasta \$15k');
    state.sort = 'Recomendadas';
    await state.refresh();

    final q = seen.single.url.queryParameters;
    expect(seen.single.url.path, '/meetings');
    expect(q['q'], 'der');
    expect(q['subject'], 'Cálculo');
    expect(q['time_of_day'], 'Mañana');
    expect(q['modality'], 'Presencial');
    expect(q['price_max'], '15000');
    expect(q['sort'], 'recommended');
    expect(state.results.length, 2);
    expect(state.error, isNull);
    expect(state.loading, isFalse);
    state.dispose();
  });

  test('error de red deja mensaje y lista vacía (no datos inventados)', () async {
    installFakeApi((r) async => jsonResponse({'code': 'x', 'message': 'Servidor caído'}, 500));
    final state = AppState();
    await state.refresh();
    expect(state.error, 'Servidor caído');
    expect(state.results, isEmpty);
    state.dispose();
  });

  test('join actualiza la reunión con la respuesta del servidor', () async {
    installFakeApi((r) async {
      if (r.url.path.endsWith('/join')) return jsonResponse(meetingJson(spots: 3, joined: true));
      if (r.url.path == '/users/me/summary') {
        return jsonResponse({
          'sessions_completed': 0, 'hours_completed': 0,
          'week': {'scheduled': 1, 'hours': 2.0, 'completed': 0},
          'subjects': [{'name': 'Cálculo', 'upcoming': 1}],
          'next_meeting': null,
        });
      }
      return jsonResponse([meetingJson(spots: 3, joined: true)]);
    });
    final state = AppState();
    final m = Meeting.fromJson(meetingJson());
    final version = AppServices.instance.dataVersion.value;
    final error = await state.join(m);
    expect(error, isNull);
    expect(m.joined, isTrue);
    expect(state.summary!.weekScheduled, 1);
    expect(AppServices.instance.dataVersion.value, greaterThan(version)); // avisa a Calendario/Historial/Perfil
    state.dispose();
  });

  test('join devuelve el mensaje del servidor si no hay cupos', () async {
    installFakeApi((r) async {
      if (r.url.path.endsWith('/join')) {
        return jsonResponse({'code': 'no_spots', 'message': 'La reunión no tiene cupos disponibles'}, 409);
      }
      return jsonResponse([]);
    });
    final state = AppState();
    final m = Meeting.fromJson(meetingJson());
    expect(await state.join(m), 'La reunión no tiene cupos disponibles');
    expect(m.joined, isFalse);
    state.dispose();
  });

  test('createMeeting envía fecha/hora en formato de la API', () async {
    final seen = installFakeApi((r) async {
      if (r.method == 'POST') return jsonResponse(meetingJson(), 201);
      if (r.url.path == '/users/me/summary') {
        return jsonResponse({
          'sessions_completed': 0, 'hours_completed': 0,
          'week': {'scheduled': 0, 'hours': 0, 'completed': 0},
          'subjects': [], 'next_meeting': null,
        });
      }
      return jsonResponse([]);
    });
    final state = AppState();
    final error = await state.createMeeting(
      title: 'Repaso', subject: 'Cálculo', description: 'x', date: DateTime(2026, 11, 20),
      start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 10, minute: 30),
      isVirtual: true, location: 'Meet', capacity: 5, price: 0,
    );
    expect(error, isNull);
    final post = seen.firstWhere((r) => r.method == 'POST');
    expect(post.body, contains('"date":"2026-11-20"'));
    expect(post.body, contains('"start_time":"09:00"'));
    expect(post.body, contains('"end_time":"10:30"'));
    state.dispose();
  });

  test('updateMeeting hace PUT a /meetings/{id} y devuelve el error del servidor', () async {
    final seen = installFakeApi((r) async {
      if (r.method == 'PUT') {
        return jsonResponse({
          'code': 'locked_has_registrations',
          'message': 'Con personas inscritas no se puede cambiar la materia ni el precio'
        }, 409);
      }
      return jsonResponse([]);
    });
    final state = AppState();
    final m = Meeting.fromJson(meetingJson(createdByMe: true));
    final error = await state.updateMeeting(
      m, title: 'Nuevo', subject: 'Cálculo', description: 'x', date: DateTime(2026, 11, 21),
      start: const TimeOfDay(hour: 16, minute: 0), end: const TimeOfDay(hour: 18, minute: 0),
      isVirtual: false, location: 'Aula 3', capacity: 8, price: 1000,
    );
    expect(error, contains('no se puede cambiar'));
    final put = seen.firstWhere((r) => r.method == 'PUT');
    expect(put.url.path, '/meetings/${m.id}');
    expect(put.body, contains('"date":"2026-11-21"'));
    expect(put.body, contains('"start_time":"16:00"'));
    state.dispose();
  });
}
 