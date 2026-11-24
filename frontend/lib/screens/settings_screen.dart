import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import 'auth_screen.dart';
import 'availability_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'edit_subjects_screen.dart';

// ============================================================
// PANTALLA 7: AJUSTES
// Secciones: CUENTA, PREFERENCIAS y SESIÓN.
// ============================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _soon(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Qué datos guarda la aplicación (según la base de datos del proyecto).
  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacidad'),
        content: const SingleChildScrollView(
          child: Text(
            'Study With Me guarda: tu nombre, username, correo y rol; tu contraseña '
            'protegida (nunca en texto plano); tus materias, intereses y disponibilidad; '
            'las reuniones que creas, a las que te unes o que guardas; y los pagos simulados '
            '(solo el monto: no hay cobros reales ni se guardan datos de tarjeta).\n\n'
            'Los códigos de verificación se guardan protegidos (no en claro) y vencen a los 10 minutos. '
            'Otras personas solo ven tu nombre como anfitrión de una reunión; tu correo no se muestra.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido')),
        ],
      ),
    );
  }

  // Cerrar sesión: volvemos al login y borramos el historial de pantallas.
  void _logout() {
    AppServices.instance.logout(); // borra el token y los datos de la sesión
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _title(),
            const SizedBox(height: 24),

            _sectionLabel('CUENTA'),
            _SettingsTile(
              icon: Icons.edit_outlined,
              title: 'Editar perfil',
              subtitle: 'Nombre y username',
              onTap: () => _open(const EditProfileScreen()),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Cambiar contraseña',
              subtitle: 'Actualiza tu acceso',
              onTap: () => _open(const ChangePasswordScreen()),
            ),
            _SettingsTile(
              icon: Icons.menu_book_outlined,
              title: 'Mis materias',
              subtitle: 'Lo que dominas y lo que quieres aprender',
              onTap: () => _open(const EditSubjectsScreen()),
            ),
            _SettingsTile(
              icon: Icons.event_available_outlined,
              title: 'Disponibilidad',
              subtitle: 'Cuándo puedes estudiar',
              onTap: () => _open(const AvailabilityScreen()),
            ),

            _sectionLabel('PREFERENCIAS'),
            _SettingsTile(
              icon: Icons.notifications_none,
              title: 'Notificaciones',
              subtitle: 'Próximamente',
              // Aún no existen notificaciones: el interruptor queda desactivado.
              trailing: const Switch(value: false, onChanged: null),
              onTap: () => _soon('Las notificaciones estarán disponibles próximamente'),
            ),
            _SettingsTile(
              icon: Icons.wb_sunny_outlined,
              title: 'Apariencia',
              subtitle: 'Claro · Modo oscuro próximamente',
              onTap: () => _soon('El modo oscuro estará disponible próximamente'),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Privacidad',
              subtitle: 'Qué datos guardamos',
              onTap: _showPrivacy,
            ),

            _sectionLabel('SESIÓN'),
            _SettingsTile(
              icon: Icons.chevron_left,
              title: 'Cerrar sesión',
              color: AppColors.danger,
              showArrow: false,
              onTap: _logout,
            ),

            const SizedBox(height: 28),
            const Center(
              child: Text('Study With Me · Versión 1.0.0',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // Flecha atrás + "Ajustes" + subtítulo
  Widget _title() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajustes',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text('Personaliza tu experiencia',
                style: TextStyle(color: AppColors.textLight)),
          ],
        ),
      ],
    );
  }

  // Título pequeño de sección (CUENTA, PREFERENCIAS...)
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 0, 8),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5)),
    );
  }
}

// Una fila de ajustes: icono + título + subtítulo + (flecha o interruptor)
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.primary,
    this.trailing,
    this.showArrow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = color == AppColors.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            IconBox(icon: icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isDanger ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      color: isDanger ? AppColors.danger : AppColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showArrow)
              const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}