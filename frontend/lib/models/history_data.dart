import 'meeting.dart';

// ============================================================
// MODELOS DE LA PANTALLA HISTORIAL
// (reuniones pasadas y movimientos de dinero; vienen de la API)
// ============================================================

/// Una reunión del pasado.
class HistoryMeeting {
  final String title;
  final String subject;
  final DateTime date;
  final bool createdByMe; // true = "Creada por ti", false = "Asististe"
  final bool cancelled;

  factory HistoryMeeting.fromJson(Map<String, dynamic> j) => HistoryMeeting(
        j['title'] as String,
        j['subject'] as String,
        parseApiDate(j['date'] as String),
        createdByMe: j['created_by_me'] as bool,
        cancelled: j['cancelled'] as bool,
      );

  const HistoryMeeting(
    this.title,
    this.subject,
    this.date, {
    this.createdByMe = false,
    this.cancelled = false,
  });
}

/// Un movimiento de dinero (positivo = ingreso, negativo = salida).
class Payment {
  final String title;
  final String subject;
  final String detail; // "Pago de Mariana Cruz"
  final DateTime date;
  final int amount;

  const Payment(this.title, this.subject, this.detail, this.date, this.amount);

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        j['title'] as String,
        j['subject'] as String,
        j['detail'] as String,
        parseApiDate(j['date'] as String),
        (j['amount'] as num).toInt(),
      );

  bool get isIncome => amount > 0;
}
