import 'package:flutter_test/flutter_test.dart';
import 'package:study_with_me/services/api_client.dart';
import 'package:study_with_me/services/app_services.dart';

import 'test_helpers.dart';

void main() {
  test('envía el token y decodifica acentos', () async {
    final seen = installFakeApi((r) async => jsonResponse({'ok': 'Física'}));
    AppServices.instance.api.token = 'abc';
    final data = await AppServices.instance.api.get('/x', query: {'q': 'á'});
    expect(data['ok'], 'Física');
    expect(seen.single.headers['Authorization'], 'Bearer abc');
    expect(seen.single.url.queryParameters['q'], 'á');
  });

  test('errores del servidor se vuelven ApiException con código y mensaje', () async {
    installFakeApi((r) async =>
        jsonResponse({'code': 'no_spots', 'message': 'Sin cupos'}, 409));
    expect(
      AppServices.instance.api.post('/meetings/1/join'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'no_spots')
          .having((e) => e.status, 'status', 409)
          .having((e) => e.message, 'message', 'Sin cupos')),
    );
  });

  test('login guarda token y usuario; logout los borra', () async {
    final seen = installFakeApi((r) async => jsonResponse({
          'access_token': 'tok',
          'token_type': 'bearer',
          'user': {
            'id': 'u1', 'full_name': 'Laura Sánchez', 'username': 'laura',
            'email': 'laura@uni.edu', 'role': 'monitor',
            'subjects': ['Cálculo'], 'interests': [], 'availability': [],
          },
        }));
    await AppServices.instance.login('laura@uni.edu', 'clave-segura-1');
    expect(seen.single.url.path, '/auth/login');
    expect(AppServices.instance.isLoggedIn, isTrue);
    expect(AppServices.instance.user!.firstName, 'Laura');
    expect(AppServices.instance.user!.isMonitor, isTrue);
    AppServices.instance.logout();
    expect(AppServices.instance.isLoggedIn, isFalse);
  });
}
