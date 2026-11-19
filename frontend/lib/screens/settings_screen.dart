import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import 'auth_screen.dart';

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
  bool _notifications = true; // interruptor de notificaciones

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
              subtitle: 'Nombre, foto y username',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Cambiar contraseña',
              subtitle: 'Actualiza tu acceso',
              onTap: () {},
            ),

            _sectionLabel('PREFERENCIAS'),
            _SettingsTile(
              icon: Icons.notifications_none,
              title: 'Notificaciones',
              subtitle: 'Recordatorios y novedades',
              // En lugar de flecha, mostramos un interruptor
              trailing: Switch(
                value: _notifications,
                activeColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _notifications = v),
              ),
            ),
            _SettingsTile(
              icon: Icons.wb_sunny_outlined,
              title: 'Apariencia',
              subtitle: 'Claro · Predeterminado',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Privacidad',
              subtitle: 'Controla tus datos',
              onTap: () {},
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
