import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/meeting.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';

// ============================================================
// PANTALLA: NUEVA REUNIÓN
// Formulario para publicar una reunión. Al publicarla aparece
// en la lista de Buscar. Las reuniones de estudiantes son gratis.
// Si se le pasa [editing], el mismo formulario edita esa reunión.
// ============================================================
class CreateMeetingScreen extends StatefulWidget {
  final AppState state;
  final Meeting? editing; // null = reunión nueva

  const CreateMeetingScreen({super.key, required this.state, this.editing});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  bool _saving = false;

  String? _subject;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _isVirtual = false;

  bool get _isEditing => widget.editing != null;

  // Con personas ya inscritas el servidor no deja cambiar materia ni precio.
  bool get _locked => (widget.editing?.taken ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final m = widget.editing;
    if (m != null) {
      _titleController.text = m.title;
      _descriptionController.text = m.description;
      _locationController.text = m.location;
      _capacityController.text = m.capacity.toString();
      _priceController.text = m.price == 0 ? '' : m.price.toString();
      _subject = m.subject;
      _date = m.date;
      _start = m.start;
      _end = m.end;
      _isVirtual = m.isVirtual;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ---------- Selectores de fecha y hora ----------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? kToday,
      firstDate: (_date != null && _date!.isBefore(kToday)) ? _date! : kToday,
      lastDate: DateTime(kToday.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  // ---------- Publicar ----------

  Future<void> _publish() async {
    final capacity = int.tryParse(_capacityController.text.trim());
    final isMonitor = AppServices.instance.user?.isMonitor ?? false;
    final price =
        isMonitor ? (int.tryParse(_priceController.text.trim()) ?? 0) : 0;

    // Validaciones: mostramos el primer error encontrado.
    String? error;
    if (_titleController.text.trim().isEmpty) {
      error = 'Escribe un título para la reunión';
    } else if (_subject == null) {
      error = 'Elige la materia';
    } else if (_date == null) {
      error = 'Elige la fecha';
    } else if (_start == null || _end == null) {
      error = 'Elige la hora inicial y final';
    } else if (_end!.hour * 60 + _end!.minute <=
        _start!.hour * 60 + _start!.minute) {
      error = 'La hora final debe ser después de la inicial';
    } else if (_locationController.text.trim().isEmpty) {
      error = 'Indica la ubicación';
    } else if (capacity == null || capacity < 1) {
      error = 'Escribe el aforo máximo (un número)';
    } else if (isMonitor && _priceController.text.trim().isNotEmpty &&
        int.tryParse(_priceController.text.trim()) == null) {
      error = 'El precio debe ser un número (en pesos)';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final description = _descriptionController.text.trim();
    setState(() => _saving = true);
    // El servidor guarda la reunión; el anfitrión es quien inició sesión.
    final desc =
        description.isEmpty ? 'Sesión de estudio en grupo.' : description;
    final editing = widget.editing;
    final String? serverError;
    if (editing == null) {
      serverError = await widget.state.createMeeting(
        title: _titleController.text.trim(),
        subject: _subject!,
        description: desc,
        date: _date!,
        start: _start!,
        end: _end!,
        isVirtual: _isVirtual,
        location: _locationController.text.trim(),
        capacity: capacity!, // ya validado arriba: nunca es null aquí
        price: price,
      );
    } else {
      serverError = await widget.state.updateMeeting(
        editing,
        title: _titleController.text.trim(),
        subject: _subject!,
        description: desc,
        date: _date!,
        start: _start!,
        end: _end!,
        isVirtual: _isVirtual,
        location: _locationController.text.trim(),
        capacity: capacity!,
        price: price,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (serverError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(serverError)));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_isEditing ? 'Cambios guardados' : '¡Reunión publicada!')),
    );
  }

  // ---------- Pantalla ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Título', required: true),
                  _textField(_titleController, 'Ej. Repaso para el parcial'),
                  _label('Materia', required: true),
                  _subjectDropdown(),
                  if (_locked)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Ya hay personas inscritas: la materia y el precio no se pueden cambiar.',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ),
                  _label('Descripción'),
                  _textField(_descriptionController,
                      'Cuenta brevemente qué estudiarán...',
                      lines: 4),
                  _label('Fecha', required: true),
                  _pickerBox(
                    text: _date == null
                        ? 'dd/mm/aaaa'
                        : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                    icon: Icons.calendar_month_outlined,
                    filled: _date != null,
                    onTap: _pickDate,
                  ),
                  Row(
                    children: [
                      Expanded(child: _timeField('Hora inicial', _start, true)),
                      const SizedBox(width: 12),
                      Expanded(child: _timeField('Hora final', _end, false)),
                    ],
                  ),
                  _label('Modalidad'),
                  _modalitySelector(),
                  const SizedBox(height: 16),
                  _label('Ubicación', required: true),
                  _textField(
                    _locationController,
                    _isVirtual
                        ? 'Enlace de la reunión'
                        : 'Edificio, sala o punto de encuentro',
                  ),
                  _label('Aforo máximo', required: true),
                  _textField(_capacityController, '8 personas',
                      keyboard: TextInputType.number),
                  // Los monitores pueden poner precio; las reuniones de
                  // estudiantes siempre son gratuitas.
                  if (AppServices.instance.user?.isMonitor ?? false) ...[
                    _label('Precio por persona (COP)'),
                    _textField(_priceController, '0 = gratis',
                        keyboard: TextInputType.number, enabled: !_locked),
                  ] else ...[
                    const SizedBox(height: 4),
                    _freeNotice(),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                      text: _saving
                          ? (_isEditing ? 'Guardando...' : 'Publicando...')
                          : (_isEditing ? 'Guardar cambios' : 'Publicar reunión'),
                      onPressed: _saving ? () {} : _publish),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Encabezado blanco con flecha atrás
  Widget _header() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chevron_left),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isEditing ? 'Editar reunión' : 'Nueva reunión',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  Text(
                      _isEditing
                          ? 'Actualiza los datos de tu reunión'
                          : 'Comparte y aprendan juntos',
                      style: const TextStyle(color: AppColors.textLight)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Título del campo, con * roja si es obligatorio
  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
          children: [
            if (required)
              const TextSpan(
                  text: ' *', style: TextStyle(color: AppColors.danger)),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int lines = 1,
    TextInputType keyboard = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: _decoration(hint),
    );
  }

  Widget _subjectDropdown() {
    return DropdownButtonFormField<String>(
      value: _subject,
      isExpanded: true,
      hint: const Text('Selecciona una materia'),
      decoration: _decoration(''),
      items: [
        for (final s in AppState.subjects)
          DropdownMenuItem(value: s, child: Text(s)),
      ],
      onChanged: _locked ? null : (v) => setState(() => _subject = v),
    );
  }

  // Caja que abre un selector (fecha u hora)
  Widget _pickerBox({
    required String text,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E4EF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text,
                style: TextStyle(
                    color: filled ? AppColors.text : AppColors.textLight)),
            Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: true),
        _pickerBox(
          text: value == null ? '--:-- --' : formatTime(value),
          icon: Icons.access_time,
          filled: value != null,
          onTap: () => _pickTime(isStart: isStart),
        ),
      ],
    );
  }

  // Selector "Presencial | Virtual"
  Widget _modalitySelector() {
    Widget option(String text, bool virtual) {
      final selected = _isVirtual == virtual;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _isVirtual = virtual),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [option('Presencial', false), option('Virtual', true)]),
    );
  }

  // Aviso verde "Reunión gratuita"
  Widget _freeNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.programacion.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.check, color: AppColors.programacion),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reunión gratuita',
                    style: TextStyle(
                        color: AppColors.programacion,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                SizedBox(height: 2),
                Text(
                  'Las reuniones creadas por estudiantes siempre son gratuitas.',
                  style: TextStyle(color: AppColors.programacion, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
