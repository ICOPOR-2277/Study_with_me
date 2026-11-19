import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'main_shell.dart';

// ============================================================
// CONTENEDOR DE AUTENTICACIÓN
// Dibuja el encabezado azul + las pestañas "Iniciar sesión / Crear cuenta"
// y muestra dentro el formulario correspondiente:
//   - Pestaña 0 -> LoginForm      (pantalla 1)
//   - Pestaña 1 -> RegisterForm   (pantallas 2 y 3)
// ============================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _tab = 0; // 0 = Iniciar sesión, 1 = Crear cuenta

  // Al iniciar sesión vamos a la app principal.
  void _goToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  // Al crear cuenta vamos a verificar el correo.
  void _goToVerify(String email) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo azul en la parte de arriba
          Container(height: 330, color: AppColors.primary),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 28),
                  _card(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Logo + frase
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary, size: 34),
            ),
            const SizedBox(width: 14),
            const Text(
              'Study\nWith Me',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Tu universidad se estudia mejor en\ncompañía.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  // Tarjeta blanca con pestañas y formulario
  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _tabs(),
          const SizedBox(height: 22),
          if (_tab == 0)
            LoginForm(onSubmit: _goToApp, onNeedsVerification: _goToVerify)
          else
            RegisterForm(onSubmit: _goToVerify),
        ],
      ),
    );
  }

  // Selector "Iniciar sesión | Crear cuenta"
  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _tabButton('Iniciar sesión', 0),
          _tabButton('Crear cuenta', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: selected ? AppColors.primary : AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }
}
