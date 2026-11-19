import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// PANTALLA 1: INICIAR SESIÓN
// Formulario con correo, contraseña y botón de entrar.
// Se muestra dentro de la tarjeta de AuthScreen.
// Al entrar llama a la API (POST /auth/login).
// ============================================================
class LoginForm extends StatefulWidget {
  final VoidCallback onSubmit; // qué hacer cuando el inicio de sesión salió bien
  // Si la cuenta existe pero falta verificar el correo, se abre esa pantalla.
  final void Function(String email)? onNeedsVerification;

  const LoginForm({super.key, required this.onSubmit, this.onNeedsVerification});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Escribe tu correo y tu contraseña');
      return;
    }
    setState(() => _loading = true);
    try {
      await AppServices.instance.login(email, password);
      if (!mounted) return;
      widget.onSubmit();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_verified' && widget.onNeedsVerification != null) {
        _showMessage(e.message);
        // La contraseña era correcta pero falta verificar: pedimos un código nuevo
        // (el anterior pudo vencer). Si pidió uno hace pocos segundos, el servidor
        // responde 429 y simplemente seguimos con el código ya enviado.
        try {
          await AppServices.instance.resendCode(email);
        } on ApiException catch (_) {}
        if (!mounted) return;
        widget.onNeedsVerification!(email);
      } else {
        _showMessage(e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: 'Correo universitario',
          hint: 'laura@universidad.edu',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        LabeledField(
          label: 'Contraseña',
          hint: '••••••••',
          controller: _passwordController,
          obscure: true,
        ),

        // Enlace "¿Olvidaste tu contraseña?" (pendiente: la API aún no lo incluye)
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        PrimaryButton(
          text: _loading ? 'Entrando...' : 'Entrar a Study With Me',
          onPressed: _loading ? () {} : _submit,
        ),
        const SizedBox(height: 14),

        const Center(
          child: Text(
            'Al continuar aceptas nuestros términos y política de privacidad.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
