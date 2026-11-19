import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// PANTALLAS 2 y 3: CREAR CUENTA
//   - Pantalla 2: rol "Estudiante" seleccionado
//   - Pantalla 3: rol "Monitor" seleccionado (aparecen las materias)
// Es el mismo formulario; cambia según el rol elegido.
// ============================================================
class RegisterForm extends StatefulWidget {
  // Se llama cuando la cuenta se creó en el servidor y entrega el correo escrito.
  final void Function(String email) onSubmit;

  const RegisterForm({super.key, required this.onSubmit});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  bool _isMonitor = false; // false = Estudiante, true = Monitor
  final Set<String> _selectedSubjects = {};
  static const int _maxSubjects = 3;

  static const _subjects = [
    'Cálculo',
    'Programación',
    'Física',
    'Inglés',
    'Bases de datos',
    'Matemáticas',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Marca o desmarca una materia (máximo 3).
  void _toggleSubject(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        _selectedSubjects.remove(subject);
      } else if (_selectedSubjects.length < _maxSubjects) {
        _selectedSubjects.add(subject);
      }
    });
  }

  // Valida los campos (las mismas reglas que el servidor) y crea la cuenta.
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().replaceFirst('@', '');
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? error;
    if (name.isEmpty) {
      error = 'Escribe tu nombre completo';
    } else if (!RegExp(r'^[A-Za-z0-9_.]{3,30}$').hasMatch(username)) {
      error = 'El username debe tener 3-30 caracteres: letras, números, _ o .';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      error = 'Escribe un correo válido';
    } else if (password.length < 8) {
      error = 'La contraseña debe tener mínimo 8 caracteres';
    } else if (_isMonitor && _selectedSubjects.isEmpty) {
      error = 'Elige al menos una materia que dominas';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _loading = true);
    try {
      await AppServices.instance.register(
        fullName: name,
        username: username,
        email: email,
        password: password,
        role: _isMonitor ? 'monitor' : 'student',
        subjects: _isMonitor ? _selectedSubjects.toList() : const [],
      );
      if (!mounted) return;
      widget.onSubmit(email);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photoPicker(),
        const SizedBox(height: 20),
        LabeledField(
            label: 'Nombre completo',
            hint: 'Laura Sánchez',
            controller: _nameController),
        LabeledField(
            label: 'Username',
            hint: '@lauraestudia',
            controller: _usernameController),
        LabeledField(
          label: 'Correo universitario',
          hint: 'laura@universidad.edu',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        LabeledField(
          label: 'Contraseña',
          hint: 'Mínimo 8 caracteres',
          controller: _passwordController,
          obscure: true,
        ),
        const Text('¿Cómo usarás la app?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _roleSelector(),
        // Las materias solo se piden si es Monitor
        if (_isMonitor) ...[
          const SizedBox(height: 20),
          _subjectsSection(),
        ],
        const SizedBox(height: 22),
        PrimaryButton(
          text: _loading ? 'Creando cuenta...' : 'Crear mi cuenta',
          onPressed: _loading ? () {} : _submit,
        ),
      ],
    );
  }

  // Cuadro de foto de perfil (opcional)
  Widget _photoPicker() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withAlpha(90)),
          ),
          child: const Icon(Icons.photo_camera_outlined,
              color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto de perfil',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Opcional · JPG o PNG',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  // Las dos tarjetas: Estudiante | Monitor
  Widget _roleSelector() {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            icon: Icons.person_outline,
            title: 'Estudiante',
            subtitle: 'Aprende en grupo',
            selected: !_isMonitor,
            onTap: () => setState(() => _isMonitor = false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleCard(
            icon: Icons.groups_outlined,
            title: 'Monitor',
            subtitle: 'Enseña y comparte',
            selected: _isMonitor,
            onTap: () => setState(() => _isMonitor = true),
          ),
        ),
      ],
    );
  }

  // "Materias que dominas  0/3" + chips
  Widget _subjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Materias que dominas',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '${_selectedSubjects.length}/$_maxSubjects',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final subject in _subjects)
              ChoiceChip(
                label: Text(subject),
                selected: _selectedSubjects.contains(subject),
                onSelected: (_) => _toggleSubject(subject),
                selectedColor: AppColors.primarySoft,
                backgroundColor: AppColors.field,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _selectedSubjects.contains(subject)
                      ? AppColors.primary
                      : AppColors.text,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Tarjeta de rol (Estudiante / Monitor)
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.field,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textLight),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.primary : AppColors.textLight,
                )),
          ],
        ),
      ),
    );
  }
}
