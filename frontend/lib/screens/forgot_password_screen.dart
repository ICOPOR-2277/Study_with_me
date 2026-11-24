import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// ¿OLVIDASTE TU CONTRASEÑA?
// Paso 1: escribes tu correo y te enviamos un código.
// Paso 2: escribes el código y la contraseña nueva.
// Usa POST /auth/forgot-password y POST /auth/reset-password.
// ============================================================
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail; // el que ya estaba escrito en el login

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newController = TextEditingController();
  final _repeatController = TextEditingController();
  bool _codeSent = false; // false = paso 1, true = paso 2
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Paso 1 (y "Reenviar código"): pide el código al servidor.
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage('Escribe tu correo');
      return;
    }
    setState(() => _loading = true);
    try {
      await AppServices.instance.forgotPassword(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _showMessage('Si el correo está registrado, te enviamos un código.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Paso 2: cambia la contraseña con el código recibido.
  Future<void> _reset() async {
    final code = _codeController.text.trim();
    final next = _newController.text;
    if (code.length != 6) {
      _showMessage('Escribe los 6 dígitos del código');
      return;
    }
    if (next.length < 8) {
      _showMessage('La contraseña nueva debe tener al menos 8 caracteres');
      return;
    }
    if (next != _repeatController.text) {
      _showMessage('Las contraseñas no coinciden');
      return;
    }
    setState(() => _loading = true);
    try {
      await AppServices.instance
          .resetPassword(_emailController.text.trim(), code, next);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Contraseña actualizada. Ya puedes iniciar sesión.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ScreenHeader(
              title: 'Recuperar contraseña',
              subtitle: _codeSent
                  ? 'Escribe el código que te enviamos'
                  : 'Te enviaremos un código a tu correo',
            ),
            const SizedBox(height: 20),
            LabeledField(
              label: 'Correo universitario',
              hint: 'laura@universidad.edu',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            if (!_codeSent)
              PrimaryButton(
                text: _loading ? 'Enviando...' : 'Enviar código',
                onPressed: _loading ? () {} : _sendCode,
              )
            else ...[
              LabeledField(
                label: 'Código de 6 dígitos',
                hint: '123456',
                controller: _codeController,
                keyboardType: TextInputType.number,
              ),
              LabeledField(
                label: 'Contraseña nueva',
                hint: 'Mínimo 8 caracteres',
                controller: _newController,
                obscure: true,
              ),
              LabeledField(
                label: 'Repite la contraseña nueva',
                hint: '••••••••',
                controller: _repeatController,
                obscure: true,
              ),
              PrimaryButton(
                text: _loading ? 'Guardando...' : 'Cambiar contraseña',
                onPressed: _loading ? () {} : _reset,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _sendCode,
                  child: const Text('Reenviar código',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}