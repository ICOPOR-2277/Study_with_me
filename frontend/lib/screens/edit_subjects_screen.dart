import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// MIS MATERIAS
//  - Monitores: "Materias que dominas" (de 1 a 3)  -> PUT /users/me/subjects
//  - Todos: "Materias que me interesan"            -> PUT /users/me/interests
// Los intereses alimentan las recomendaciones de Buscar.
// ============================================================
class EditSubjectsScreen extends StatefulWidget {
  const EditSubjectsScreen({super.key});

  @override
  State<EditSubjectsScreen> createState() => _EditSubjectsScreenState();
}

class _EditSubjectsScreenState extends State<EditSubjectsScreen> {
  static const _all = [
    'Cálculo',
    'Programación',
    'Física',
    'Inglés',
    'Bases de datos',
    'Matemáticas',
  ];
  static const _maxExpertise = 3;

  late final Set<String> _expertise;
  late final Set<String> _interests;
  bool _saving = false;

  UserProfile? get _user => AppServices.instance.user;
  bool get _isMonitor => _user?.isMonitor ?? false;

  @override
  void initState() {
    super.initState();
    _expertise = {...?_user?.subjects};
    _interests = {...?_user?.interests};
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_isMonitor && _expertise.isEmpty) {
      _showMessage('Elige al menos una materia que dominas');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isMonitor) {
        await AppServices.instance.saveSubjects(_expertise.toList());
      }
      await AppServices.instance.saveInterests(_interests.toList());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Materias guardadas')));
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
                title: 'Mis materias',
                subtitle: 'Personaliza tus recomendaciones'),
            const SizedBox(height: 20),
            if (_isMonitor) ...[
              _title('Materias que dominas',
                  '${_expertise.length}/$_maxExpertise'),
              const SizedBox(height: 12),
              _chips(_expertise, max: _maxExpertise),
              const SizedBox(height: 24),
            ],
            _title('Materias que me interesan', '${_interests.length}'),
            const SizedBox(height: 12),
            _chips(_interests),
            const SizedBox(height: 28),
            PrimaryButton(
              text: _saving ? 'Guardando...' : 'Guardar materias',
              onPressed: _saving ? () {} : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text, String counter) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(counter,
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _chips(Set<String> selected, {int? max}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final subject in _all)
          ChoiceChip(
            label: Text(subject),
            selected: selected.contains(subject),
            onSelected: (_) => setState(() {
              if (selected.contains(subject)) {
                selected.remove(subject);
              } else if (max == null || selected.length < max) {
                selected.add(subject);
              }
            }),
            selectedColor: AppColors.primarySoft,
            backgroundColor: AppColors.field,
            side: BorderSide.none,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected.contains(subject)
                  ? AppColors.primary
                  : AppColors.text,
            ),
          ),
      ],
    );
  }
}