import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_with_me/services/app_services.dart';

import 'profile_api_test.dart' show userJson;
import 'test_helpers.dart';

void main() {
  test('sin token guardado no hay sesión y no se llama a la API', () async {
    SharedPreferences.setMockInitialValues({});
    final seen = installFakeApi((r) async => jsonResponse({}));
    expect(await AppServices.instance.restoreSession(), isFalse);
    expect(seen, isEmpty);
  });

  test('con token válido se retoma la sesión con GET /users/me', () async {
    SharedPreferences.setMockInitialValues({'swm_token': 'abc'});
    final seen = installFakeApi((r) async => jsonResponse(userJson()));
    expect(await AppServices.instance.restoreSession(), isTrue);
    expect(seen.single.url.path, '/users/me');
    expect(seen.single.headers['Authorization'], 'Bearer abc');
    expect(AppServices.instance.isLoggedIn, isTrue);
  });

  test('token vencido (401) se descarta', () async {
    SharedPreferences.setMockInitialValues({'swm_token': 'viejo'});
    installFakeApi((r) async => jsonResponse(
        {'code': 'invalid_token', 'message': 'Sesión vencida'}, 401));
    expect(await AppServices.instance.restoreSession(), isFalse);
    expect((await SharedPreferences.getInstance()).getString('swm_token'), isNull);
  });

  test('error del servidor (503) conserva el token para reintentar', () async {
    SharedPreferences.setMockInitialValues({'swm_token': 'abc'});
    installFakeApi((r) async => jsonResponse({'message': 'dormido'}, 503));
    expect(await AppServices.instance.restoreSession(), isFalse);
    expect((await SharedPreferences.getInstance()).getString('swm_token'), 'abc');
  });
}