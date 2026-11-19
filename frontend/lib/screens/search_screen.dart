import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/meeting.dart';
import '../theme/app_colors.dart';
import '../widgets/pill_chip.dart';
import 'create_meeting_screen.dart';
import 'filter_sheet.dart';
import 'meeting_detail_sheet.dart';

// ============================================================
// PANTALLA: BUSCAR ("Explorar")  -- INTERACTIVA
//   - Escribe en el buscador y la lista se filtra al instante
//   - Chips de materia para filtrar rápido
//   - Botón de filtros (panel con horario, día, modalidad y precio)
//   - Ordenar (más próximas / menor precio / más cupos)
//   - Guardar reuniones con el marcador
//   - Tocar una tarjeta abre el detalle
//   - Botón "+" para crear una reunión nueva
// ============================================================
class SearchScreen extends StatefulWidget {
  final AppState state;

  const SearchScreen({super.key, required this.state});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  AppState get state => widget.state;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        // Si el estado limpió la búsqueda (ej. desde Inicio), vaciamos el campo.
        // (se hace después de dibujar para no modificar el campo durante el build)
        if (state.query.isEmpty && _searchController.text.isNotEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _searchController.clear());
        }
        final results = state.results;

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: _createButton(),
          body: Column(
            children: [
              _header(),
              _countAndSort(results.length),
              Expanded(
                child: state.loading && results.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null && results.isEmpty
                        ? _errorState()
                        : results.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: results.length,
                        itemBuilder: (_, i) => _MeetingCard(
                          meeting: results[i],
                          state: state,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Encabezado: título, buscador y chips ----------

  Widget _header() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Explorar',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: Text('Encuentra tu próxima sesión',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _searchField()),
                      const SizedBox(width: 10),
                      _filterButton(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _subjectChips(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: state.setQuery,
      decoration: InputDecoration(
        hintText: 'Materia, tema o monitor...',
        hintStyle: const TextStyle(color: AppColors.textLight),
        prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
        // La "x" para borrar aparece solo si hay texto
        suffixIcon: state.query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchController.clear();
                  state.setQuery('');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE3E4EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE3E4EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  // Botón morado de filtros (con puntito amarillo si hay filtros activos)
  Widget _filterButton() {
    return GestureDetector(
      onTap: () => showFilterSheet(context, state),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
          if (state.filters.hasAdvanced)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2C230),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Fila de chips: Todas | Cálculo | Programación ...
  Widget _subjectChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          PillChip(
            label: 'Todas',
            selected: state.filters.subject == null,
            onTap: () => state.setSubject(null),
          ),
          for (final s in AppState.subjects) ...[
            const SizedBox(width: 8),
            PillChip(
              label: s,
              selected: state.filters.subject == s,
              onTap: () => state.setSubject(s),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- "6 reuniones disponibles" + ordenar ----------

  Widget _countAndSort(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count ${count == 1 ? 'reunión disponible' : 'reuniones disponibles'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          PopupMenuButton<String>(
            onSelected: state.setSort,
            itemBuilder: (_) => [
              for (final o in AppState.sortOptions)
                PopupMenuItem(value: o, child: Text(o)),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(state.sort,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12)),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: AppColors.textLight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cuando falló la carga (sin conexión, servidor dormido, etc.)
  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(state.error ?? 'No se pudieron cargar las reuniones.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: state.refresh,
              child: const Text('Reintentar',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // Cuando no hay resultados
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off,
                size: 56, color: AppColors.textLight),
            const SizedBox(height: 12),
            const Text('No encontramos reuniones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Prueba con otra palabra o quita algunos filtros.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                state.setQuery('');
                state.setFilters(SearchFilters());
              },
              child: const Text('Limpiar búsqueda',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // Botón "+" para crear reunión
  Widget _createButton() {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreateMeetingScreen(state: state)),
      ),
      child: const Icon(Icons.add, size: 30),
    );
  }
}

// ============================================================
// TARJETA DE UNA REUNIÓN en la lista de Buscar
// ============================================================
class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final AppState state;

  const _MeetingCard({required this.meeting, required this.state});

  @override
  Widget build(BuildContext context) {
    final m = meeting;
    final color = AppColors.subject(m.subject);

    return GestureDetector(
      onTap: () => showMeetingDetail(context, state, m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja de color de la materia a la izquierda
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _topRow(context, m),
                        Text(m.title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        _hostRow(m),
                        const SizedBox(height: 12),
                        _detailsBox(m),
                        const SizedBox(height: 12),
                        _bottomRow(context, m),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Etiqueta de materia + marcador de guardado
  Widget _topRow(BuildContext context, Meeting m) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SubjectTag(m.subject),
        IconButton(
          onPressed: () async {
            final error = await state.toggleSaved(m);
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error)));
            }
          },
          icon: Icon(
            m.saved ? Icons.bookmark : Icons.bookmark_border,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // "Por  Mariana Cruz"
  Widget _hostRow(Meeting m) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(m.hostInitials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Por',
                style: TextStyle(color: AppColors.textLight, fontSize: 10)),
            Text(m.host,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  // Cuadro gris con fecha, hora, modalidad y cupos
  Widget _detailsBox(Meeting m) {
    Widget item(IconData icon, String text) {
      return Expanded(
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(children: [
            item(Icons.calendar_today_outlined, shortDate(m.date)),
            item(Icons.access_time, formatTime(m.start)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            item(m.isVirtual ? Icons.link : Icons.location_on_outlined,
                m.modality),
            item(Icons.groups_outlined,
                m.spots == 0 ? 'Sin cupos' : '${m.spots} cupos'),
          ]),
        ],
      ),
    );
  }

  // Precio + "Ver detalles >"
  Widget _bottomRow(BuildContext context, Meeting m) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(formatPrice(m.price),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        GestureDetector(
          onTap: () => showMeetingDetail(context, state, m),
          child: const Row(
            children: [
              Text('Ver detalles',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}
