const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const _monthsLong = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// "29 Septiembre 2026"
String formatLongDate(DateTime d) =>
    '${d.day} ${_monthsLong[d.month - 1]} ${d.year}';

String _two(int n) => n.toString().padLeft(2, '0');

/// "29 sep 2026"
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "29 sep 2026, 08:30"
String formatDateTime(DateTime d) =>
    '${formatDate(d)}, ${_two(d.hour)}:${_two(d.minute)}';

/// "Hoy, 08:30" / "Ayer, 08:30" / "29 sep, 08:30"
String formatRelativeDateTime(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final time = '${_two(d.hour)}:${_two(d.minute)}';
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy, $time';
  if (diff == 1) return 'Ayer, $time';
  if (d.year == now.year) return '${d.day} ${_months[d.month - 1]}, $time';
  return formatDateTime(d);
}

String greetingForTime([DateTime? at]) {
  final h = (at ?? DateTime.now()).hour;
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}
