import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_with_me/services/api_client.dart';
import 'package:study_with_me/services/app_services.dart';

/// Meeting tal como lo devuelve la API (GET /meetings).
Map<String, dynamic> meetingJson({
  String id = '11111111-1111-1111-1111-111111111111',
  String title = 'Derivadas sin miedo',
  String subject = 'Cálculo',
  int price = 15000,
  int spots = 4,
  bool joined = false,
  bool saved = false,
  bool createdByMe = false,
}) =>
    {
      'id': id,
      'title': title,
      'subject': subject,
      'host': 'Mariana Cruz',
      'host_id': '22222222-2222-2222-2222-222222222222',
      'description': 'Repaso',
      'date': '2026-11-20',
      'start_time': '09:00',
      'end_time': '11:00',
      'is_virtual': false,
      'location': 'Biblioteca Central · Sala 204',
      'capacity': 8,
      'price': price,
      'spots': spots,
      'saved': saved,
      'joined': joined,
      'created_by_me': createdByMe,
      'status': 'scheduled',
    };

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Instala un ApiClient con servidor falso. [handler] recibe cada petición.
List<http.Request> installFakeApi(
    Future<http.Response> Function(http.Request) handler) {
  final seen = <http.Request>[];
  AppServices.instance.api = ApiClient(
    baseUrl: 'http://test',
    client: MockClient((req) async {
      seen.add(req);
      return handler(req);
    }),
  );
  AppServices.instance.user = null;
  return seen;
}
