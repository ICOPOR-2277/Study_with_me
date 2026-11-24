import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/app_services.dart';

// Punto de entrada de la app.
// Arranca mostrando la pantalla de autenticación (Login / Crear cuenta).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Si había una sesión guardada y el servidor la acepta, se entra directo.
  final restored = await AppServices.instance.restoreSession();
  runApp(StudyWithMeApp(startLoggedIn: restored));
}

class StudyWithMeApp extends StatelessWidget {
  final bool startLoggedIn;

  const StudyWithMeApp({super.key, this.startLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study With Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: startLoggedIn ? const MainShell() : const AuthScreen(),
    );
  }
}