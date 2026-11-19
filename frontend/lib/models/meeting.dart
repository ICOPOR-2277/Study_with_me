import 'package:flutter/material.dart';

// ============================================================
// MODELO DE REUNIÓN + funciones para dar formato a fechas, horas y precios.
// ============================================================

// "Hoy": la fecha real (sin hora). Antes estaba fija en el 21 de septiembre
// para coincidir con el diseño; con datos reales debe ser la fecha actual.
DateTime get kToday {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _weekdaysLong = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
];
const _monthsShort = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
];
const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre'
];

/// "Lun, 21 Sep"
String shortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]}';

/// "Lunes, 21 de septiembre"
String longDate(DateTime d) =>
    '${_weekdaysLong[d.weekday - 1]}, ${d.day} de ${_monthsLong[d.month - 1]}';

/// "21 Sep 2026"
String dayMonthYear(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

/// "21 Sep"
String dayMonth(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

/// "9:00 AM"
String formatTime(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minutes = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minutes $period';
}

/// 15000 -> "15.000"
String formatMoney(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 15000 -> "$15.000"   |   0 -> "Gratis"
String formatPrice(int price) =>
    price == 0 ? 'Gratis' : '\$${formatMoney(price)}';

/// "Mariana Cruz" -> "MC"
String initialsOf(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

// ---------- Conversión desde/hacia la API ----------

/// "2026-11-18" -> DateTime(2026, 11, 18)
DateTime parseApiDate(String value) {
  final p = value.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// "2026-11-18" (para enviar a la API)
String formatApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "15:00" o "15:00:00" -> TimeOfDay(15, 0)
TimeOfDay parseApiTime(String value) {
  final p = value.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// "15:00" (para enviar a la API)
String formatApiTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Una reunión de estudio.
class Meeting {
  final String id;
  final String title;
  final String subject;
  final String host; // quién la creó
  final String description;
  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool isVirtual;
  final String location;
  final int capacity; // aforo máximo
  final int price; // 0 = gratis
  final String hostId; // id de quien la creó (uuid como texto)
  final bool createdByMe; // la creé yo
  String status; // 'scheduled' | 'cancelled'

  int spots; // cupos disponibles (baja cuando alguien se une)
  bool saved; // guardada por el usuario
  bool joined; // el usuario ya se unió

  Meeting({
    required this.id,
    required this.title,
    required this.subject,
    required this.host,
    required this.description,
    required this.date,
    required this.start,
    required this.end,
    required this.isVirtual,
    required this.location,
    required this.capacity,
    required this.spots,
    required this.price,
    this.hostId = '',
    this.createdByMe = false,
    this.status = 'scheduled',
    this.saved = false,
    this.joined = false,
  });

  /// Construye la reunión a partir del JSON de la API.
  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String,
        host: j['host'] as String,
        hostId: j['host_id'] as String,
        description: (j['description'] ?? '') as String,
        date: parseApiDate(j['date'] as String),
        start: parseApiTime(j['start_time'] as String),
        end: parseApiTime(j['end_time'] as String),
        isVirtual: j['is_virtual'] as bool,
        location: j['location'] as String,
        capacity: (j['capacity'] as num).toInt(),
        spots: (j['spots'] as num).toInt(),
        price: (j['price'] as num).toInt(),
        createdByMe: j['created_by_me'] as bool,
        status: j['status'] as String,
        saved: j['saved'] as bool,
        joined: j['joined'] as bool,
      );

  /// Copia los datos que cambian (cupos, guardada, inscrito, estado) desde la
  /// versión que devolvió el servidor. Se actualiza el MISMO objeto para que
  /// los paneles abiertos se redibujen sin perder la referencia.
  void updateFrom(Meeting other) {
    spots = other.spots;
    saved = other.saved;
    joined = other.joined;
    status = other.status;
  }

  String get hostInitials => initialsOf(host);
  String get modality => isVirtual ? 'Virtual' : 'Presencial';
  String get timeRange => '${formatTime(start)} – ${formatTime(end)}';
  int get taken => capacity - spots; // personas ya inscritas

  /// Momento exacto en que empieza (sirve para ordenar).
  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, start.hour, start.minute);

  /// "Mañana", "Tarde" o "Noche" según la hora de inicio.
  String get timeOfDay {
    if (start.hour < 12) return 'Mañana';
    if (start.hour < 18) return 'Tarde';
    return 'Noche';
  }
}
