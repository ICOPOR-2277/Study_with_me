import 'package:flutter/material.dart';

import '../models/meeting.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';

// ============================================================
// PANTALLA 5: CALENDARIO
// Tiene dos vistas: Semana y Mes (se cambian con el selector).
// Muestra las reuniones en las que participas (las creaste o te uniste),
// que se piden a la API (GET /calendar) para el rango visible.
// ============================================================

// Un evento del calendario (una sesión de estudio).
class CalendarEvent {
  final DateTime date;
  final String title;
  final Color color;

  const CalendarEvent(this.date, this.title, this.color);
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // "Hoy": la fecha real (antes estaba fija en el 21 de septiembre del diseño).
  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _shortMonths = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul',
    'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  static const _weekDays = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];

  // Eventos del rango visible, traídos de la API.
  List<CalendarEvent> _events = [];
  String? _error;

  bool _isMonthView = true; // true = Mes, false = Semana
  DateTime _focused = _today; // fecha que estamos mirando

  @override
  void initState() {
    super.initState();
    _load();
    // Se recarga cuando creas una reunión o te unes a una.
    AppServices.instance.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    AppServices.instance.dataVersion.removeListener(_load);
    super.dispose();
  }

  // Primer y último día que se ven en pantalla (en el mes incluye días de relleno).
  (DateTime, DateTime) _visibleRange() {
    if (!_isMonthView) {
      final start = _startOfWeek(_focused);
      return (start, start.add(const Duration(days: 6)));
    }
    final first = DateTime(_focused.year, _focused.month, 1);
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final leading = first.weekday % 7;
    final weeks = ((leading + daysInMonth) / 7).ceil();
    final gridStart = first.subtract(Duration(days: leading));
    return (gridStart, gridStart.add(Duration(days: weeks * 7 - 1)));
  }

  Future<void> _load() async {
    if (!AppServices.instance.isLoggedIn) return;
    final (from, to) = _visibleRange();
    try {
      final data = await AppServices.instance.api.get('/calendar', query: {
        'from': formatApiDate(from),
        'to': formatApiDate(to),
      }) as List;
      if (!mounted) return;
      setState(() {
        _error = null;
        _events = [
          for (final j in data)
            CalendarEvent(
              parseApiDate((j as Map<String, dynamic>)['date'] as String),
              j['title'] as String,
              AppColors.subject(j['subject'] as String),
            ),
        ];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  // ---------- Ayudas de fechas ----------

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<CalendarEvent> _eventsOf(DateTime day) =>
      _events.where((e) => _sameDay(e.date, day)).toList();

  // Domingo de la semana de una fecha (la semana empieza en domingo).
  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday % 7));

  // ---------- Acciones ----------

  void _goToday() {
    setState(() => _focused = _today);
    _load();
  }

  void _move(int direction) {
    setState(() {
      if (_isMonthView) {
        _focused = DateTime(_focused.year, _focused.month + direction, 1);
      } else {
        _focused = _focused.add(Duration(days: 7 * direction));
      }
    });
    _load();
  }

  // Texto del centro: "21 – 27 Sep" (semana) o "Septiembre 2026" (mes)
  String get _rangeLabel {
    if (_isMonthView) {
      return '${_monthNames[_focused.month - 1]} ${_focused.year}';
    }
    final start = _startOfWeek(_focused);
    final end = start.add(const Duration(days: 6));
    return '${start.day} – ${end.day} ${_shortMonths[end.month - 1]}';
  }

  // ---------- Pantalla ----------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendario',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Organiza tu semana',
                style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 22),
            _topBar(),
            const SizedBox(height: 16),
            _viewSelector(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            _isMonthView ? _monthView() : _weekView(),
          ],
        ),
      ),
    );
  }

  // Fila: botón "Hoy" + flechas con el rango de fechas
  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _goToday,
          child: const Text('Hoy',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
        Row(
          children: [
            IconButton(
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left)),
            Text(_rangeLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ],
    );
  }

  // Selector "Semana | Mes"
  Widget _viewSelector() {
    Widget option(String text, bool isMonth) {
      final selected = _isMonthView == isMonth;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _isMonthView = isMonth);
            _load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: selected ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [option('Semana', false), option('Mes', true)]),
    );
  }

  // ---------- Vista MES ----------

  Widget _monthView() {
    final firstOfMonth = DateTime(_focused.year, _focused.month, 1);
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final leading = firstOfMonth.weekday % 7; // días del mes anterior visibles
    final weeks = ((leading + daysInMonth) / 7).ceil();
    final gridStart = firstOfMonth.subtract(Duration(days: leading));

    return Column(
      children: [
        // Letras D L M M J V S
        Row(
          children: [
            for (final d in _weekDays)
              Expanded(
                child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Una fila por semana
        for (int w = 0; w < weeks; w++)
          Row(
            children: [
              for (int d = 0; d < 7; d++)
                Expanded(
                  child: _dayCell(gridStart.add(Duration(days: w * 7 + d))),
                ),
            ],
          ),
      ],
    );
  }

  // Una casilla de día: número + (si hay) la etiqueta del evento
  Widget _dayCell(DateTime day) {
    final inMonth = day.month == _focused.month;
    final isToday = _sameDay(day, _today);
    final events = _eventsOf(day);

    return SizedBox(
      height: 78,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? Colors.white
                    : (inMonth
                        ? AppColors.text
                        : AppColors.textLight.withAlpha(110)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final e in events) _eventChip(e),
        ],
      ),
    );
  }

  // Etiqueta pequeña de color con el nombre del evento
  Widget _eventChip(CalendarEvent e) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: e.color.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Container(width: 2.5, height: 12, color: e.color),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w700, color: e.color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Vista SEMANA ----------

  Widget _weekView() {
    final start = _startOfWeek(_focused);

    return Column(
      children: [
        for (int i = 0; i < 7; i++) _weekRow(start.add(Duration(days: i))),
      ],
    );
  }

  // Una fila por día: "L 21" + sus eventos
  Widget _weekRow(DateTime day) {
    final isToday = _sameDay(day, _today);
    final events = _eventsOf(day);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : AppColors.field,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${_weekDays[day.weekday % 7]}\n${day.day}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isToday ? Colors.white : AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: events.isEmpty
                ? const Text('Sin sesiones',
                    style: TextStyle(color: AppColors.textLight))
                : Column(
                    children: [for (final e in events) _bigEventChip(e)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bigEventChip(CalendarEvent e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: e.color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: e.color),
          const SizedBox(width: 10),
          Text(e.title,
              style: TextStyle(fontWeight: FontWeight.w800, color: e.color)),
        ],
      ),
    );
  }
}
