import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import 'main_shell.dart';

// ============================================================
// PANTALLA 4: VERIFICA TU CORREO
// Pide el código de 6 dígitos y tiene un contador para reenviarlo.
// ============================================================
class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _waitSeconds = 48;

  int _secondsLeft = _waitSeconds;
  Timer? _timer;
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // Cuenta regresiva de 48 segundos para poder reenviar el código.
  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _waitSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Envía el código a la API; si es correcto, la API inicia sesión y entramos.
  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage('Escribe los 6 dígitos del código');
      return;
    }
    setState(() => _loading = true);
    try {
      await AppServices.instance.verifyEmail(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Pide un código nuevo y reinicia la cuenta regresiva.
  Future<void> _resend() async {
    try {
      await AppServices.instance.resendCode(widget.email);
      if (!mounted) return;
      _startCountdown();
      _showMessage('Te enviamos un nuevo código');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  // "laura@universidad.edu" -> "lau•••@universidad.edu"
  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final name = parts[0];
    final visible = name.length > 3 ? name.substring(0, 3) : name;
    return '$visible•••@${parts[1]}';
  }

  // Formato 00:48
  String get _timeText {
    final s = _secondsLeft.toString().padLeft(2, '0');
    return '00:$s';
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.text),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _envelopeIcon(),
              const SizedBox(height: 32),
              const Text(
                'Verifica tu correo',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Enviamos un código de seis dígitos a\n$_maskedEmail',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 32),
              _codeField(),
              const SizedBox(height: 28),
              PrimaryButton(
                text: _loading ? 'Verificando...' : 'Verificar código',
                onPressed: _loading ? () {} : _verify,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No recibiste nada? ',
                      style: TextStyle(color: AppColors.textLight)),
                  GestureDetector(
                    onTap: canResend ? _resend : null,
                    child: Text(
                      'Reenviar código',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: canResend
                            ? AppColors.primary
                            : AppColors.primary.withAlpha(160),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!canResend)
                Text(
                  'Podrás solicitar otro código en $_timeText',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Sobre azul con puntitos de colores alrededor
  Widget _envelopeIcon() {
    return SizedBox(
      width: 150,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.mail_outline,
                size: 52, color: AppColors.primary),
          ),
          Positioned(top: 4, right: 14, child: _dot(const Color(0xFFF2C230))),
          Positioned(bottom: 24, left: 6, child: _dot(const Color(0xFFE4608A))),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // Campo para escribir los 6 dígitos
  Widget _codeField() {
    return TextField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 12),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••••',
        hintStyle: const TextStyle(color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
