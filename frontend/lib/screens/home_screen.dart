import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/meeting.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import 'meeting_detail_sheet.dart';

// ============================================================
// PANTALLA: INICIO  -- INTERACTIVA
//   - Tarjeta de "Próxima sesión" (Ver detalles abre el panel)
//   - Mis materias: tocar una abre Buscar filtrado por esa materia
//   - "Ver todas" -> Buscar  |  "Abrir calendario" -> Calendario
//   - Resumen de la semana (cambia al unirte a reuniones)
// ============================================================
class HomeScreen extends StatelessWidget {
  final AppState state;

  const HomeScreen({super.key, required this.state});

  // Símbolo de cada materia en el carrusel (el número de sesiones viene de la API).
  static const _symbols = {
    'Cálculo': '∫',
    'Programación': '</>',
    'Física': 'F',
    'Inglés': 'Aa',
    'Bases de datos': 'DB',
    'Matemáticas': '∑',
  };

  // 9.0 -> "9", 9.5 -> "9.5"
  static String _hours(double h) =>
      h == h.roundToDouble() ? '${h.toInt()}' : h.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final next = state.nextMeeting;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _greeting(),
                const SizedBox(height: 20),
                if (next != null) _nextSessionCard(context, next),
                const SizedBox(height: 24),
                _sectionTitle('Mis materias', 'Ver todas', () {
                  state.setSubject(null); // sin filtro de materia
                  state.goToTab(1); // ir a Buscar
                }),
                const SizedBox(height: 12),
                _subjectsRow(state.summary?.subjects ?? const []),
                const SizedBox(height: 24),
                _sectionTitle('Esta semana', 'Abrir calendario',
                    () => state.goToTab(2)),
                const SizedBox(height: 12),
                _weekSummary(),
                const SizedBox(height: 20),
                _tipCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Saludo ----------

  Widget _greeting() {
    final name = AppServices.instance.user?.firstName ?? '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name.isEmpty ? 'Hola 👋' : 'Hola, $name 👋',
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('¿Qué aprenderemos hoy?',
                style: TextStyle(color: AppColors.textLight)),
          ],
        ),
      ],
    );
  }

  // ---------- Tarjeta "Próxima sesión" ----------

  Widget _nextSessionCard(BuildContext context, Meeting m) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A45E0), Color(0xFF7B4DEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PRÓXIMA SESIÓN',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 7, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(m.subject,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(m.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(m.timeRange,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(width: 18),
              Icon(m.isVirtual ? Icons.link : Icons.location_on_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  m.isVirtual ? 'Virtual' : m.location.split('·').last.trim(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withAlpha(60), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Avatares de asistentes
              Row(
                children: [
                  _avatar(m.hostInitials),
                  // Personas ya inscritas: "+N"
                  if (m.taken > 0) _avatar('+${m.taken}'),
                ],
              ),
              GestureDetector(
                onTap: () => showMeetingDetail(context, state, m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text('Ver detalles',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      Icon(Icons.chevron_right, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(String text) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6A45E0), width: 2),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w800)),
    );
  }

  // ---------- Títulos de sección ----------

  Widget _sectionTitle(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        GestureDetector(
          onTap: onTap,
          child: Text(action,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  // ---------- Mis materias (carrusel horizontal) ----------

  Widget _subjectsRow(List<SubjectCount> subjects) {
    if (subjects.isEmpty) {
      return const SizedBox(
        height: 142,
        child: Center(
          child: Text('Cargando tus materias...',
              style: TextStyle(color: AppColors.textLight)),
        ),
      );
    }
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final name = subjects[i].name;
          final sessions = subjects[i].upcoming;
          final symbol = _symbols[name] ?? name.substring(0, 1);
          final color = AppColors.subject(name);
          return GestureDetector(
            onTap: () => state.openSearchWithSubject(name),
            child: Container(
              width: 124,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(symbol,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('$sessions ${sessions == 1 ? 'sesión' : 'sesiones'}',
                          style: TextStyle(
                              color: color.withAlpha(170), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Resumen de la semana ----------

  Widget _weekSummary() {
    // Cifras de la semana (domingo a sábado) calculadas por el servidor.
    final week = state.summary;

    Widget row(IconData icon, Color color, String title, String subtitle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          row(Icons.calendar_today_outlined, AppColors.primary,
              '${week?.weekScheduled ?? 0} sesiones', 'Agendadas'),
          const Divider(height: 1, color: Color(0xFFEDEEF5)),
          row(Icons.access_time, AppColors.programacion,
              '${_hours(week?.weekHours ?? 0)} horas', 'De estudio'),
          const Divider(height: 1, color: Color(0xFFEDEEF5)),
          row(Icons.check, AppColors.matematicas,
              '${week?.weekCompleted ?? 0} completadas', '¡Buen ritmo!'),
        ],
      ),
    );
  }

  // ---------- Tip de hoy ----------

  Widget _tipCard() {
    Widget bar(double height, Color color) => Container(
          width: 12,
          height: height,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TIP DE HOY',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFF8A6D1F))),
                SizedBox(height: 8),
                Text(
                  'Estudiar en bloques de 50 minutos mejora tu concentración.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bar(30, AppColors.matematicas),
              bar(48, AppColors.primary),
              bar(26, AppColors.basesDatos),
            ],
          ),
        ],
      ),
    );
  }
}
