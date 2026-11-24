import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_with_me/models/app_state.dart';
import 'package:study_with_me/models/meeting.dart';
import 'package:study_with_me/services/api_client.dart';
import 'package:study_with_me/services/app_services.dart';

import 'test_helpers.dart';

Map<String, dynamic> userJson({
  String name = 'Laura Sánchez',
  String username = 'laura',
  List<Map<String, dynamic>> availability = const [],
}) =>
    {
      'id': '33333333-3333-3333-3333-333333333333',
      'full_name': name,
      'username': username,
      'email': 'laura@uni.edu',
      'role': 'student',
      'subjects': <String>[],
      'interests': ['Cálculo'],
      'availability': availability,
    };

void main() {
  test('updateProfile hace PUT /users/me y actualiza el usuario', () async {
    final seen = installFakeApi((r) async =>
        jsonResponse(userJson(name: 'Laura Gil', username: 'lauragil')));
    await AppServices.instance
        .updateProfile(fullName: 'Laura Gil', username: 'lauragil');
    final put = seen.single;
    expect(put.method, 'PUT');
    expect(put.url.path, '/users/me');
    expect(put.body, contains('"username":"lauragil"'));
    expect(AppServices.instance.user?.fullName, 'Laura Gil');
  });

  test('changePassword envía la actual y la nueva; el error llega como ApiException', () async {
    final seen = installFakeApi((r) async => jsonResponse(
        {'code': 'wrong_password', 'message': 'La contraseña actual no es correcta'},
        400));
    await expectLater(
      AppServices.instance.changePassword('mala', 'nueva-clave-9'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'wrong_password')),
    );
    expect(seen.single.url.path, '/users/me/password');
    expect(seen.single.body, contains('"current_password":"mala"'));
    expect(seen.single.body, contains('"new_password":"nueva-clave-9"'));
  });

  test('forgotPassword y resetPassword usan los endpoints de /auth', () async {
    final seen = installFakeApi((r) async => jsonResponse({'message': 'ok'}));
    await AppServices.instance.forgotPassword('laura@uni.edu');
    await AppServices.instance
        .resetPassword('laura@uni.edu', '123456', 'nueva-clave-9');
    expect(seen[0].url.path, '/auth/forgot-password');
    expect(seen[1].url.path, '/auth/reset-password');
    expect(seen[1].body, contains('"code":"123456"'));
    expect(seen[1].body, contains('"new_password":"nueva-clave-9"'));
  });

  test('saveAvailability envía las franjas en formato HH:MM y las lee de vuelta', () async {
    final slots = [
      const AvailabilitySlot(
          weekday: 0,
          start: TimeOfDay(hour: 8, minute: 0),
          end: TimeOfDay(hour: 10, minute: 30)),
    ];
    final seen = installFakeApi((r) async => jsonResponse(userJson(availability: [
          {'weekday': 0, 'start_time': '08:00', 'end_time': '10:30'}
        ])));
    await AppServices.instance.saveAvailability(slots);
    expect(seen.single.url.path, '/users/me/availability');
    expect(seen.single.body, contains('"start_time":"08:00"'));
    expect(seen.single.body, contains('"end_time":"10:30"'));
    final back = AppServices.instance.user!.availability.single;
    expect(back.weekday, 0);
    expect(back.end, const TimeOfDay(hour: 10, minute: 30));
  });

  test('cancelMeeting hace POST /meetings/{id}/cancel', () async {
    final seen = installFakeApi((r) async {
      if (r.url.path == '/users/me/summary') {
        return jsonResponse({
          'sessions_completed': 0, 'hours_completed': 0,
          'week': {'scheduled': 0, 'hours': 0, 'completed': 0},
          'subjects': [], 'next_meeting': null,
        });
      }
      if (r.method == 'POST') return jsonResponse(meetingJson(createdByMe: true));
      return jsonResponse([]);
    });
    final state = AppState();
    final m = Meeting.fromJson(meetingJson(createdByMe: true));
    final error = await state.cancelMeeting(m);
    expect(error, isNull);
    expect(seen.firstWhere((r) => r.method == 'POST').url.path,
        '/meetings/${m.id}/cancel');
    state.dispose();
  });
}