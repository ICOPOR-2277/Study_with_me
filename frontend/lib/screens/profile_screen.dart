import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import 'settings_screen.dart';

// ============================================================
// PANTALLA 6: PERFIL
// Encabezado azul con avatar, tarjeta de estadísticas,
// datos de contacto, materias, logros y botón "Editar perfil".
// ============================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Datos de la persona que inició sesión (vienen de la API al entrar).
  UserProfile? get _user => AppServices.instance.user;
  String get _name => _user?.fullName ?? '';
  String get _username => '@${_user?.username ?? ''}';
  String get _email => _user?.email ?? '';
  String get _role => (_user?.isMonitor ?? false) ? 'Monitor' : 'Estudiante';
  String get _roleBadge =>
      (_user?.isMonitor ?? false) ? 'Monitor académico' : 'Estudiante';
  String get _initials => _user?.initials ?? '?';
  // Monitor: materias que domina. Estudiante: materias que le interesan.
  List<String> get _subjects => (_user?.isMonitor ?? false)
      ? (_user?.subjects ?? const [])
      : (_user?.interests ?? const []);

  Summary? _summary; // sesiones y horas (GET /users/me/summary)

  @override
  void initState() {
    super.initState();
    _load();
    AppServices.instance.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    AppServices.instance.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!AppServices.instance.isLoggedIn) return;
    try {
      final data = await AppServices.instance.api.get('/users/me/summary')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _summary = Summary.fromJson(data));
    } on ApiException {
      // Sin cifras: se muestran guiones.
    }
  }

  // 32.0 -> "32", 7.5 -> "7.5"
  String _hoursText(double h) =>
      h == h.roundToDouble() ? '${h.toInt()}' : h.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _header(context),
          // Zona gris con esquinas redondeadas arriba, sobre fondo azul
          Container(
            color: AppColors.primary,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statsCard(),
                  const SizedBox(height: 20),
                  _infoRow(Icons.mail_outline, 'Correo', _email),
                  _infoRow(Icons.person_outline, 'Rol', _role),
                  const SizedBox(height: 12),
                  const SectionHeader(title: 'Mis materias', actionText: 'Editar'),
                  const SizedBox(height: 14),
                  _subjectChips(),
                  const SizedBox(height: 26),
                  const SectionHeader(title: 'Logros', actionText: 'Ver todos'),
                  const SizedBox(height: 16),
                  _achievements(),
                  const SizedBox(height: 24),
                  _editButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Encabezado azul ----------
  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              // Logo (izquierda) y engranaje de ajustes (derecha)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _roundIcon(Icons.bar_chart_rounded, filled: true),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: _roundIcon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _avatar(),
              const SizedBox(height: 14),
              Text(_name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_username,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_roleBadge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {bool filled = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: filled ? Colors.white.withAlpha(235) : Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon,
          color: filled ? AppColors.primary : Colors.white, size: 24),
    );
  }

  // Avatar con iniciales y cámara
  Widget _avatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 108,
          height: 108,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Text(_initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
        ),
        Positioned(
          right: -6,
          bottom: -6,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.photo_camera_outlined,
                size: 18, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ---------- Estadísticas: 18 / 32h / 4.9 ----------
  Widget _statsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
              child: _Stat(
                  value: _summary == null ? '—' : '${_summary!.sessionsCompleted}',
                  label: 'Sesiones')),
          Expanded(
              child: _Stat(
                  value: _summary == null
                      ? '—'
                      : '${_hoursText(_summary!.hoursCompleted)}h',
                  label: 'Estudiadas')),
          // La valoración aún no existe como función en el proyecto.
          const Expanded(child: _Stat(value: '—', label: 'Valoración')),
        ],
      ),
    );
  }

  // ---------- Fila de información (Correo / Rol) ----------
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Materias ----------
  Widget _subjectChips() {
    if (_subjects.isEmpty) {
      return const Text('Aún no has elegido materias.',
          style: TextStyle(color: AppColors.textLight));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in _subjects)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.subject(s).withAlpha(28),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.subject(s)),
                const SizedBox(width: 6),
                Text(s,
                    style: TextStyle(
                        color: AppColors.subject(s),
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- Logros ----------
  Widget _achievements() {
    return const Row(
      children: [
        // Pendiente: los logros todavía no tienen una función que los calcule.
        Expanded(child: _Achievement(value: '—', label: 'Sesiones')),
        Expanded(child: _Achievement(value: '—', label: 'En equipo')),
        Expanded(child: _Achievement(value: '—', label: 'Top monitor')),
      ],
    );
  }

  // ---------- Botón Editar perfil ----------
  Widget _editButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: TextButton.icon(
        onPressed: () {},
        style: TextButton.styleFrom(
          backgroundColor: AppColors.primarySoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
        label: const Text('Editar perfil',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// Un número grande con su etiqueta debajo (18 / Sesiones)
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
      ],
    );
  }
}

// Un logro: número dentro de un cuadro azul claro + etiqueta
class _Achievement extends StatelessWidget {
  final String value;
  final String label;

  const _Achievement({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
      ],
    );
  }
}
