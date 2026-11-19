import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../theme/app_colors.dart';
import 'calendar_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

// ============================================================
// BARRA DE NAVEGACIÓN INFERIOR
// Contiene las 5 pestañas: Inicio, Buscar, Calendario, Historial, Perfil.
// Aquí se crea el AppState (estado compartido) y se reparte a las pantallas
// que lo necesitan (Inicio y Buscar).
// ============================================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final AppState _state = AppState();

  // Una página por cada pestaña, en el mismo orden que la barra.
  late final List<Widget> _pages = [
    HomeScreen(state: _state),
    SearchScreen(state: _state),
    const CalendarScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Primera carga de datos desde la API (reuniones y cifras de Inicio).
    _state.refresh();
    _state.loadSummary();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se redibuja cuando cambia la pestaña (ej. desde Inicio -> Buscar).
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(index: _state.tab, children: _pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _state.tab,
            onDestinationSelected: _state.goToTab,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primarySoft,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppColors.primary),
                  label: 'Inicio'),
              NavigationDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search, color: AppColors.primary),
                  label: 'Buscar'),
              NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon:
                      Icon(Icons.calendar_today, color: AppColors.primary),
                  label: 'Calendario'),
              NavigationDestination(
                  icon: Icon(Icons.history),
                  selectedIcon: Icon(Icons.history, color: AppColors.primary),
                  label: 'Historial'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: AppColors.primary),
                  label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}
