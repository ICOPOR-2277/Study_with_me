import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/history_data.dart';
import '../models/meeting.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_chip.dart';

// ============================================================
// PANTALLA: HISTORIAL  -- INTERACTIVA
// Dos pestañas:
//   - Reuniones: línea de tiempo con reuniones pasadas
//   - Pagos:     balance del mes + movimientos
// Los filtros (mes, año, materia, movimiento) funcionan de verdad y se
// aplican en el servidor (GET /history/meetings y GET /history/payments).
// ============================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  // Año actual y el anterior.
  static List<int> get _years => [DateTime.now().year - 1, DateTime.now().year];
  static const _movements = ['Todos', 'Ingresos', 'Salidas'];

  bool _showPayments = false; // false = Reuniones, true = Pagos
  int _month = DateTime.now().month; // 1..12
  int _year = DateTime.now().year;
  String? _subject; // null = todas las materias
  String _movement = 'Todos';

  // ---------- Datos (vienen de la API) ----------

  List<HistoryMeeting> _meetings = [];
  List<Payment> _payments = [];
  bool _loading = false;
  String? _error;

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

  Future<void> _load() async {
    if (!AppServices.instance.isLoggedIn) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = AppServices.instance.api;
    final base = {'year': '$_year', 'month': '$_month'};
    if (_subject != null) base['subject'] = _subject!;
    final movement = {'Ingresos': 'income', 'Salidas': 'expense'}[_movement] ?? 'all';
    try {
      final results = await Future.wait([
        api.get('/history/meetings', query: base),
        api.get('/history/payments', query: {...base, 'movement': movement}),
      ]);
      if (!mounted) return;
      setState(() {
        _meetings = [
          for (final j in results[0] as List)
            HistoryMeeting.fromJson(j as Map<String, dynamic>),
        ];
        _payments = [
          for (final j in results[1] as List)
            Payment.fromJson(j as Map<String, dynamic>),
        ];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  // ---------- Pantalla ----------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tabs(),
                const SizedBox(height: 14),
                _filters(),
                const SizedBox(height: 18),
                _showPayments ? _paymentsView() : _meetingsView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Título + botón Exportar
  Widget _header() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Historial',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Tu actividad académica',
                      style: TextStyle(color: AppColors.textLight)),
                ],
              ),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_showPayments
                        ? 'Pagos exportados (demo)'
                        : 'Reuniones exportadas (demo)'),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.download_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Exportar',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Selector "Reuniones | Pagos"
  Widget _tabs() {
    Widget option(String text, bool payments) {
      final selected = _showPayments == payments;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _showPayments = payments),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: Colors.black.withAlpha(15), blurRadius: 6),
                    ]
                  : null,
            ),
            child: Text(text,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: selected ? AppColors.primary : AppColors.textLight,
                )),
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
      child:
          Row(children: [option('Reuniones', false), option('Pagos', true)]),
    );
  }

  // ---------- Filtros desplegables ----------

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _dropdownChip<int>(
            label: _months[_month - 1],
            options: {for (int i = 1; i <= 12; i++) _months[i - 1]: i},
            onSelected: (v) {
              setState(() => _month = v);
              _load();
            },
          ),
          const SizedBox(width: 8),
          _dropdownChip<int>(
            label: '$_year',
            options: {for (final y in _years) '$y': y},
            onSelected: (v) {
              setState(() => _year = v);
              _load();
            },
          ),
          const SizedBox(width: 8),
          // (el menú no acepta valores null, por eso "todas" es un texto vacío)
          _dropdownChip<String>(
            label: _subject ?? 'Materia',
            options: {
              'Todas las materias': '',
              for (final s in AppState.subjects) s: s,
            },
            onSelected: (v) {
              setState(() => _subject = v.isEmpty ? null : v);
              _load();
            },
          ),
          // "Movimiento" solo existe en la pestaña Pagos
          if (_showPayments) ...[
            const SizedBox(width: 8),
            _dropdownChip<String>(
              label: _movement == 'Todos' ? 'Movimiento' : _movement,
              options: {for (final m in _movements) m: m},
              onSelected: (v) {
                setState(() => _movement = v);
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  // Chip que al tocarlo abre un menú de opciones
  Widget _dropdownChip<T>({
    required String label,
    required Map<String, T> options,
    required void Function(T) onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem<T>(value: entry.value, child: Text(entry.key)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E4EF)),
        ),
        child: Row(
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight)),
      ),
    );
  }

  // ============================================================
  // PESTAÑA REUNIONES: línea de tiempo
  // ============================================================

  Widget _meetingsView() {
    if (_loading) return _emptyMessage('Cargando...');
    if (_error != null) return _emptyMessage(_error!);
    final items = _meetings;
    if (items.isEmpty) {
      return _emptyMessage('No hay reuniones en este periodo.');
    }
    return Column(
      children: [for (final m in items) _timelineItem(m)],
    );
  }

  Widget _timelineItem(HistoryMeeting m) {
    final color = AppColors.subject(m.subject);
    final who = m.createdByMe ? 'Creada por ti' : 'Asististe';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Línea vertical + punto de color
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(width: 1.5, color: const Color(0xFFDADBE8)),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubjectTag(m.subject),
                    const SizedBox(height: 10),
                    Text(m.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('$who · ${dayMonthYear(m.date)}',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 11)),
                    const SizedBox(height: 10),
                    _statusChip(m.cancelled),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool cancelled) {
    final color = cancelled ? AppColors.danger : AppColors.programacion;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        cancelled ? 'Cancelada' : 'Completada',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  // ============================================================
  // PESTAÑA PAGOS: balance + movimientos
  // ============================================================

  Widget _paymentsView() {
    if (_loading) return _emptyMessage('Cargando...');
    if (_error != null) return _emptyMessage(_error!);
    final items = _payments;

    // Sumas calculadas con los movimientos visibles
    final income =
        items.where((p) => p.isIncome).fold<int>(0, (s, p) => s + p.amount);
    final expenses = items
        .where((p) => !p.isIncome)
        .fold<int>(0, (s, p) => s + p.amount.abs());
    final balance = income - expenses;

    return Column(
      children: [
        _balanceCard(balance, income, expenses),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _emptyMessage('No hay movimientos en este periodo.')
        else
          for (final p in items) _paymentTile(p),
      ],
    );
  }

  Widget _balanceCard(int balance, int income, int expenses) {
    Widget stat(Color dot, String label, int value) {
      return Padding(
        padding: const EdgeInsets.only(right: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: dot),
                const SizedBox(width: 6),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 2),
            Text('\$${formatMoney(value)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF3B2F63),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance de ${_months[_month - 1].toLowerCase()}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            '${balance < 0 ? '-' : '+'}\$${formatMoney(balance)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 34, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(AppColors.programacion, 'Ingresos', income),
              stat(AppColors.ingles, 'Salidas', expenses),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(Payment p) {
    final color = p.isIncome ? AppColors.programacion : AppColors.basesDatos;

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              p.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${p.detail} · ${dayMonth(p.date)}',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 10)),
              ],
            ),
          ),
          Text(
            '${p.isIncome ? '+' : '-'}\$${formatMoney(p.amount)}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
