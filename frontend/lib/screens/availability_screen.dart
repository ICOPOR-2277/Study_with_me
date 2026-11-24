import 'package:flutter/material.dart';

import '../models/meeting.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// DISPONIBILIDAD
// Franjas semanales en las que puedes estudiar (PUT /users/me/availability).
// Se usan para recomendarte reuniones que caen en tus horarios.
// ============================================================
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  static const _days = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  static const _maxSlots = 60; // el mismo límite del servidor

  late final List<AvailabilitySlot> _slots;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _slots = [...?AppServices.instance.user?.availability];
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // Pide hora de inicio y de fin con el selector de hora y agrega la franja.
  Future<void> _addSlot(int weekday) async {
    if (_slots.length >= _maxSlots) {
      _showMessage('Llegaste al máximo de franjas');
      return;
    }
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: '${_days[weekday]}: hora de inicio',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
      helpText: '${_days[weekday]}: hora de fin',
    );
    if (end == null || !mounted) return;
    if (_minutes(end) <= _minutes(start)) {
      _showMessage('La hora final debe ser después de la inicial');
      return;
    }
    final slot = AvailabilitySlot(weekday: weekday, start: start, end: end);
    if (_slots.any(slot.sameAs)) {
      _showMessage('Esa franja ya está agregada');
      return;
    }
    setState(() {
      _slots.add(slot);
      _slots.sort((a, b) => a.weekday != b.weekday
          ? a.weekday.compareTo(b.weekday)
          : _minutes(a.start).compareTo(_minutes(b.start)));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppServices.instance.saveAvailability(_slots);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disponibilidad guardada')));
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
                title: 'Disponibilidad',
                subtitle: 'Cuándo puedes estudiar cada semana'),
            const SizedBox(height: 16),
            for (var day = 0; day < 7; day++) _dayCard(day),
            const SizedBox(height: 12),
            PrimaryButton(
              text: _saving ? 'Guardando...' : 'Guardar disponibilidad',
              onPressed: _saving ? () {} : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(int day) {
    final daySlots = _slots.where((s) => s.weekday == day).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_days[day],
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          Expanded(
            child: daySlots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Sin franjas',
                        style: TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final s in daySlots)
                        InputChip(
                          label: Text('${formatTime(s.start)} – ${formatTime(s.end)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          backgroundColor: AppColors.primarySoft,
                          side: BorderSide.none,
                          onDeleted: () => setState(() => _slots.remove(s)),
                        ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: 'Agregar franja',
            onPressed: () => _addSlot(day),
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}