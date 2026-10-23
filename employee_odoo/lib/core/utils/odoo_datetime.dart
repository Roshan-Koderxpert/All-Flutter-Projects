/// Odoo stores datetimes as UTC strings without a timezone suffix.
class OdooDateTime {
  OdooDateTime._();

  static const double standardWorkDayHours = 8.0;

  /// Parses Odoo datetime string to local [DateTime].
  static DateTime? parse(dynamic value) {
    if (value == false || value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is! String || value.trim().isEmpty) return null;

    var raw = value.trim();
    if (!raw.contains('T')) {
      raw = raw.replaceFirst(' ', 'T');
    }
    final hasTimezone = raw.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw) ||
        RegExp(r'[+-]\d{4}$').hasMatch(raw);
    if (!hasTimezone) {
      raw = '${raw}Z';
    }

    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  /// Parses Odoo [Date] fields (YYYY-MM-DD) as a local calendar date.
  static DateTime? parseDate(dynamic value) {
    if (value == false || value == null) return null;
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final datePart = raw.split(' ').first;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(datePart);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    final parsed = parse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Formats local [DateTime] for Odoo RPC (UTC).
  static String toOdooUtc(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${utc.year}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')} '
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')}';
  }

  /// Start/end of [day] in local time, converted to Odoo UTC strings.
  static ({String start, String end}) localDayRangeUtc(DateTime day) {
    final startLocal = DateTime(day.year, day.month, day.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    return (start: toOdooUtc(startLocal), end: toOdooUtc(endLocal));
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Odoo list style: 05/26/2026 17:03:31
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    final mo = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final y = dateTime.year;
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    final s = dateTime.second.toString().padLeft(2, '0');
    return '$mo/$d/$y $h:$min:$s';
  }

  static String formatDate(DateTime dateTime) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.year}';
  }

  /// Odoo form style: 01/01/2026
  static String formatDateSlash(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final mo = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$mo/$d/${dateTime.year}';
  }

  static String formatMonthKey(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}';
  }

  /// Decimal hours → HH:MM (e.g. 4.0 → 04:00, -3.98 → -03:59)
  static String formatDurationHhMm(double hours) {
    final sign = hours < 0 ? '-' : '';
    final totalMinutes = (hours.abs() * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String formatHours(double hours) => formatDurationHhMm(hours);
}
