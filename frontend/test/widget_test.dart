import 'package:flutter_test/flutter_test.dart';
import 'package:study_with_me/main.dart';

void main() {
  testWidgets('la app arranca en la pantalla de autenticación', (tester) async {
    await tester.pumpWidget(const StudyWithMeApp());
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Entrar a Study With Me'), findsOneWidget);
  });
}
