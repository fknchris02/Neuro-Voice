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

/// Folio de evaluación: "CM26-9HTK57" (sin I, O, 0 ni 1 para evitar confusiones).
final folioPattern = RegExp(r'^CM\d{2}-[A-HJ-NP-Z2-9]{6}$');

/// Folio dentro del texto de un código QR ("CM26-9HTK57", con o sin guion);
/// null si el código no trae un folio.
String? folioFromQr(String raw) {
  final m = RegExp(r'CM\d{2}-?[A-HJ-NP-Z2-9]{6}').firstMatch(raw.toUpperCase());
  return m == null ? null : normalizeFolio(m.group(0)!);
}

/// "cm26 9htk57" → "CM26-9HTK57" (mayúsculas y guion automáticos)
String normalizeFolio(String text) {
  var s = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (s.length > 10) s = s.substring(0, 10);
  return s.length > 4 ? '${s.substring(0, 4)}-${s.substring(4)}' : s;
}
