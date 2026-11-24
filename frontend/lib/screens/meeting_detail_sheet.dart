import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_state.dart';
import '../models/meeting.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import '../widgets/pill_chip.dart';
import 'create_meeting_screen.dart';

// ============================================================
// DETALLE DE REUNIÓN (panel que sube desde abajo)
// Se abre desde Inicio ("Ver detalles") y desde Buscar (cada tarjeta).
// Permite Guardar, Compartir y Unirse.
// ============================================================

void showMeetingDetail(BuildContext context, AppState state, Meeting meeting) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _MeetingDetailSheet(state: state, meeting: meeting),
  );
}

class _MeetingDetailSheet extends StatelessWidget {
  final AppState state;
  final Meeting meeting;

  const _MeetingDetailSheet({required this.state, required this.meeting});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder redibuja el panel cuando cambia el estado
    // (por ejemplo al pulsar Guardar o Unirme).
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final m = meeting;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barrita para arrastrar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DAE6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _titleRow(m),
                const SizedBox(height: 18),
                _actionButtons(context, m),
                const SizedBox(height: 18),
                _infoGrid(m),
                const SizedBox(height: 20),
                const Text('Sobre esta reunión',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(m.description,
                    style: const TextStyle(
                        color: AppColors.textLight, height: 1.4)),
                const SizedBox(height: 20),
                _joinButton(context, m),
              ],
            ),
          ),
        );
      },
    );
  }

  // Materia + título + "Creada por" + avatar del monitor
  Widget _titleRow(Meeting m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubjectTag(m.subject),
              const SizedBox(height: 10),
              Text(m.title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: 'Creada por ',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 13),
                  children: [
                    TextSpan(
                      text: m.host,
                      style: const TextStyle(
                          color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(m.hostInitials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
      ],
    );
  }

  // Botones Guardar y Compartir
  Widget _actionButtons(BuildContext context, Meeting m) {
    return Row(
      children: [
        _outlineButton(
          icon: m.saved ? Icons.bookmark : Icons.bookmark_border,
          text: m.saved ? 'Guardada' : 'Guardar',
          onTap: () async {
            final error = await state.toggleSaved(m);
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error)));
            }
          },
        ),
        const SizedBox(width: 10),
        _outlineButton(
          icon: Icons.share_outlined,
          text: 'Compartir',
          onTap: () {
            Clipboard.setData(ClipboardData(
                text: '${m.title} · ${longDate(m.date)} · ${m.timeRange}'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enlace copiado')),
            );
          },
        ),
      ],
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E4EF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // Cuadrícula de datos: fecha, horario, lugar, cupos, precio
  Widget _infoGrid(Meeting m) {
    const border = BorderSide(color: Color(0xFFE3E4EF));

    Widget cell(IconData icon, String label, String value) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconBox(icon: icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(border),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(children: [
              cell(Icons.calendar_today_outlined, 'Fecha', longDate(m.date)),
              Container(width: 1, color: const Color(0xFFE3E4EF)),
              cell(Icons.access_time, 'Horario', m.timeRange),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE3E4EF)),
          IntrinsicHeight(
            child: Row(children: [
              cell(
                m.isVirtual ? Icons.link : Icons.location_on_outlined,
                m.modality,
                m.location,
              ),
              Container(width: 1, color: const Color(0xFFE3E4EF)),
              cell(Icons.groups_outlined, 'Cupos',
                  '${m.spots} de ${m.capacity} disponibles'),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE3E4EF)),
          Row(children: [
            cell(Icons.credit_card_outlined, 'Precio', formatPrice(m.price)),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ),
    );
  }

  // Botón "Unirme a la reunión"
  Widget _joinButton(BuildContext context, Meeting m) {
    if (m.createdByMe) {
      if (m.status != 'scheduled') return _disabledButton('Reunión cancelada');
      return Column(
        children: [
          PrimaryButton(
            text: 'Editar reunión',
            onPressed: () {
              // Cerramos el panel y abrimos el formulario con los datos actuales.
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(MaterialPageRoute(
                  builder: (_) =>
                      CreateMeetingScreen(state: state, editing: m)));
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => _confirmCancel(context, m),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Cancelar reunión',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Tú creaste esta reunión',
              style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      );
    }
    if (m.joined) {
      return _disabledButton('Ya estás inscrito ✓');
    }
    if (m.spots == 0) {
      return _disabledButton('Sin cupos disponibles');
    }
    return PrimaryButton(
      text: 'Unirme a la reunión',
      onPressed: () async {
        // El servidor confirma (cupos, pago simulado) antes de dar el mensaje.
        final error = await state.join(m);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error ?? '¡Te uniste a "${m.title}"!')),
        );
      },
    );
  }

  // Pide confirmación y cancela la reunión en el servidor.
  Future<void> _confirmCancel(BuildContext context, Meeting m) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la reunión?'),
        content: Text(
            '"${m.title}" quedará cancelada para todas las personas inscritas. '
            'Esta acción no se puede deshacer y los pagos simulados no se reembolsan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Volver')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí, cancelar',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final error = await state.cancelMeeting(m);
    messenger.showSnackBar(
        SnackBar(content: Text(error ?? 'Reunión cancelada')));
    if (error == null) navigator.pop(); // cierra el panel de detalle
  }

  Widget _disabledButton(String text) {
    return Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
    );
  }
}