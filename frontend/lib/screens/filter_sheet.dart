import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/meeting.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import '../widgets/pill_chip.dart';

// ============================================================
// PANEL "FILTRAR REUNIONES"
// Se abre con el botón de filtros de la pantalla Buscar.
// Trabaja con una COPIA de los filtros; solo se aplican al pulsar
// "Aplicar filtros".
// ============================================================

void showFilterSheet(BuildContext context, AppState state) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FilterSheet(state: state),
  );
}

class _FilterSheet extends StatefulWidget {
  final AppState state;

  const _FilterSheet({required this.state});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters draft; // copia editable de los filtros

  static const _times = ['Mañana', 'Tarde', 'Noche'];
  static const _modalities = ['Todas', 'Presencial', 'Virtual'];
  static const _prices = ['Todos', 'Gratis', 'Hasta \$15k', 'Más de \$15k'];

  @override
  void initState() {
    super.initState();
    draft = widget.state.filters.copy();
  }

  // Los 7 días a partir de hoy, para el selector "Día específico"
  List<DateTime> get _days => List.generate(
        7,
        (i) => DateTime(kToday.year, kToday.month, kToday.day + i),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _header(),
            const SizedBox(height: 18),

            _label('Materia'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in AppState.subjects)
                  PillChip(
                    label: s,
                    selected: draft.subject == s,
                    // tocar otra vez la materia seleccionada la quita
                    onTap: () => setState(
                        () => draft.subject = draft.subject == s ? null : s),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            _label('Horario'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _times)
                  PillChip(
                    label: t,
                    selected: draft.timeOfDay == t,
                    onTap: () => setState(
                        () => draft.timeOfDay = draft.timeOfDay == t ? null : t),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dayDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _modalityDropdown()),
              ],
            ),
            const SizedBox(height: 20),

            _label('Rango de precio'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _prices)
                  PillChip(
                    label: p,
                    selected: draft.price == p,
                    onTap: () => setState(() => draft.price = p),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              text: 'Aplicar filtros',
              onPressed: () {
                widget.state.setFilters(draft);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // "Filtrar reuniones" + botón Limpiar
  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Filtrar reuniones',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: () => setState(() => draft = SearchFilters()),
          child: const Text('Limpiar',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    );
  }

  Widget _dayDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Día específico'),
        DropdownButtonFormField<DateTime?>(
          value: draft.day,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          items: [
            const DropdownMenuItem<DateTime?>(
              value: null,
              child: Text('Cualquier día'),
            ),
            for (final d in _days)
              DropdownMenuItem<DateTime?>(value: d, child: Text(shortDate(d))),
          ],
          onChanged: (v) => setState(() => draft.day = v),
        ),
      ],
    );
  }

  Widget _modalityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Modalidad'),
        DropdownButtonFormField<String>(
          value: draft.modality,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          items: [
            for (final m in _modalities)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) => setState(() => draft.modality = v ?? 'Todas'),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3E4EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
