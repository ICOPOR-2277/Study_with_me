import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// CAMBIAR CONTRASEÑA (POST /users/me/password)
// Pide la contraseña actual y la nueva (mínimo 8 caracteres).
// ============================================================
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _repeatController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final current = _currentController.text;
    final next = _newController.text;
    if (current.isEmpty) {
      _showMessage('Escribe tu contraseña actual');
      return;
    }
    if (next.length < 8) {
      _showMessage('La contraseña nueva debe tener al menos 8 caracteres');
      return;
    }
    if (next != _repeatController.text) {
      _showMessage('Las contraseñas nuevas no coinciden');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppServices.instance.changePassword(current, next);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada')));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ScreenHeader(
                title: 'Cambiar contraseña', subtitle: 'Actualiza tu acceso'),
            const SizedBox(height: 20),
            LabeledField(
              label: 'Contraseña actual',
              hint: '••••••••',
              controller: _currentController,
              obscure: true,
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
            const SizedBox(height: 4),
            PrimaryButton(
              text: _saving ? 'Guardando...' : 'Cambiar contraseña',
              onPressed: _saving ? () {} : _save,
            ),
          ],
        ),
      ),
    );
  }
}