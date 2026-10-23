/// Odoo-style HH:MM from decimal hours.
String formatOdooHours(double hours) {
  final sign = hours < 0 ? '-' : '';
  final abs = hours.abs();
  final h = abs.floor();
  final m = ((abs - h) * 60).round().clamp(0, 59);
  return '$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Parses [HH:MM], [H:MM], or decimal hours.
double? parseOdooHours(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;

  if (raw.contains(':')) {
    final negative = raw.startsWith('-');
    final normalized = negative ? raw.substring(1) : raw;
    final parts = normalized.split(':');
    if (parts.length != 2) return null;

    final hoursPart = int.tryParse(parts[0].trim());
    final minutesPart = int.tryParse(parts[1].trim());
    if (hoursPart == null || minutesPart == null) return null;
    if (hoursPart < 0 || minutesPart < 0 || minutesPart >= 60) return null;

    final total = hoursPart + (minutesPart / 60.0);
    return negative ? -total : total;
  }

  return double.tryParse(raw.replaceAll(',', '.'));
}
