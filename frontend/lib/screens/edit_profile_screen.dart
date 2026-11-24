import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import 'change_password_screen.dart';
import 'edit_subjects_screen.dart';

// ============================================================
// EDITAR PERFIL
// Cambia el nombre y el username (PUT /users/me). El correo y el rol
// no se pueden cambiar. Desde aquí también se llega a "Cambiar
// contraseña" y a "Mis materias".
// ============================================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _saving = false;

  UserProfile? get _user => AppServices.instance.user;

  @override
  void initState() {
    super.initState();
    _nameController.text = _user?.fullName ?? '';
    _usernameController.text = _user?.username ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username =
        _usernameController.text.trim().replaceFirst('@', '').toLowerCase();
    if (name.isEmpty) {
      _showMessage('Escribe tu nombre');
      return;
    }
    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(username)) {
      _showMessage(
          'El username debe tener de 3 a 30 caracteres: letras, números, "_" o "."');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppServices.instance
          .updateProfile(fullName: name, username: username);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ScreenHeader(
                title: 'Editar perfil', subtitle: 'Nombre y username'),
            const SizedBox(height: 20),
            LabeledField(
              label: 'Nombre completo',
              hint: 'Laura Sánchez',
              controller: _nameController,
            ),
            LabeledField(
              label: 'Username',
              hint: 'lauraestudia',
              controller: _usernameController,
            ),
            _readOnlyRow(Icons.mail_outline, 'Correo', user?.email ?? ''),
            _readOnlyRow(Icons.person_outline, 'Rol',
                (user?.isMonitor ?? false) ? 'Monitor' : 'Estudiante'),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 18),
              child: Text('El correo y el rol no se pueden cambiar.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            ),
            PrimaryButton(
              text: _saving ? 'Guardando...' : 'Guardar cambios',
              onPressed: _saving ? () {} : _save,
            ),
            const SizedBox(height: 12),
            _linkTile(Icons.menu_book_outlined, 'Mis materias',
                () => const EditSubjectsScreen()),
            _linkTile(Icons.lock_outline, 'Cambiar contraseña',
                () => const ChangePasswordScreen()),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconBox(icon: icon),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String title, Widget Function() screen) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: IconBox(icon: icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => screen())),
    );
  }
}