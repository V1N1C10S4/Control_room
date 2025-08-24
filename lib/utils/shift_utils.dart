/// Por qué: centraliza el cálculo de turnos (06–18 / 18–06).
class ShiftWindow {
  final DateTime start;
  final DateTime end;
  const ShiftWindow(this.start, this.end);
}

ShiftWindow currentShiftWindow([DateTime? now]) {
  final _now = now ?? DateTime.now();
  final today = DateTime(_now.year, _now.month, _now.day);
  final sixAM = DateTime(today.year, today.month, today.day, 6);
  final sixPM = DateTime(today.year, today.month, today.day, 18);

  if (_now.isAfterOrAt(sixAM) && _now.isBefore(sixPM)) {
    return ShiftWindow(sixAM, sixPM); // diurno
  } else if (_now.isAfterOrAt(sixPM)) {
    final nextSixAM = sixAM.add(const Duration(days: 1));
    return ShiftWindow(sixPM, nextSixAM); // nocturno hoy→mañana
  } else {
    // _now < 06:00 ⇒ nocturno anterior (ayer 18:00 a hoy 06:00)
    final yesterday = today.subtract(const Duration(days: 1));
    final ySixPM = DateTime(yesterday.year, yesterday.month, yesterday.day, 18);
    return ShiftWindow(ySixPM, sixAM);
  }
}

Duration durationToNextCutoff([DateTime? now]) {
  final _now = now ?? DateTime.now();
  final today = DateTime(_now.year, _now.month, _now.day);
  final sixAM = DateTime(today.year, today.month, today.day, 6);
  final sixPM = DateTime(today.year, today.month, today.day, 18);
  final next = _now.isBefore(sixAM)
      ? sixAM
      : _now.isBefore(sixPM)
          ? sixPM
          : sixAM.add(const Duration(days: 1));
  return next.difference(_now);
}

extension DateTimeX on DateTime {
  bool isAfterOrAt(DateTime other) => isAfter(other) || isAtSameMomentAs(other);
  bool isBeforeOrAt(DateTime other) => isBefore(other) || isAtSameMomentAs(other);
}