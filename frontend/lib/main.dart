import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'screens/auth_screen.dart';

// Punto de entrada de la app.
// Arranca mostrando la pantalla de autenticación (Login / Crear cuenta).
void main() {
  runApp(const StudyWithMeApp());
}

class StudyWithMeApp extends StatelessWidget {
  const StudyWithMeApp({super.key});

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
      home: const AuthScreen(),
    );
  }
}
