import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_with_me/models/history_data.dart';
import 'package:study_with_me/models/meeting.dart';

import 'test_helpers.dart';

void main() {
  test('Meeting.fromJson convierte lo que envía FastAPI', () {
    final m = Meeting.fromJson(meetingJson());
    expect(m.id, '11111111-1111-1111-1111-111111111111'); // uuid como String
    expect(m.date, DateTime(2026, 11, 20));
    expect(m.start, const TimeOfDay(hour: 9, minute: 0));
    expect(m.end, const TimeOfDay(hour: 11, minute: 0));
    expect(m.price, 15000);
    expect(m.taken, 4); // capacity 8 - spots 4
    expect(m.timeOfDay, 'Mañana');
    expect(m.hostInitials, 'MC');
  });

  test('horas y fechas de ida y vuelta con la API', () {
    expect(parseApiTime('15:30:00'), const TimeOfDay(hour: 15, minute: 30));
    expect(formatApiTime(const TimeOfDay(hour: 7, minute: 5)), '07:05');
    expect(formatApiDate(DateTime(2026, 1, 9)), '2026-01-09');
    expect(parseApiDate('2026-01-09'), DateTime(2026, 1, 9));
  });

  test('updateFrom conserva el mismo objeto y actualiza cupos', () {
    final m = Meeting.fromJson(meetingJson());
    m.updateFrom(Meeting.fromJson(meetingJson(spots: 3, joined: true)));
    expect(m.spots, 3);
    expect(m.joined, isTrue);
  });

  test('kToday es la fecha real, sin hora', () {
    final now = DateTime.now();
    expect(kToday, DateTime(now.year, now.month, now.day));
  });

  test('modelos del historial', () {
    final h = HistoryMeeting.fromJson({
      'meeting_id': 'x', 'title': 'T', 'subject': 'Física',
      'date': '2026-11-02', 'created_by_me': true, 'cancelled': false,
    });
    expect(h.createdByMe, isTrue);
    final p = Payment.fromJson({
      'meeting_id': 'x', 'title': 'T', 'subject': 'Física',
      'detail': 'Pago a Ana', 'date': '2026-11-02', 'amount': -15000,
    });
    expect(p.isIncome, isFalse);
    expect(p.amount, -15000);
  });
}
