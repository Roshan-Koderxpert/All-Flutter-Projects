import '../../core/utils/odoo_datetime.dart';

class LeaveCalendarInfoItem {
  LeaveCalendarInfoItem({
    required this.title,
    this.dateFrom,
    this.dateTo,
    this.subtitle,
  });

  final String title;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  /// e.g. company name on mandatory days (Odoo list column).
  final String? subtitle;

  String get dateLabel {
    if (dateFrom == null && dateTo == null) return 'Date not set';
    if (dateFrom != null && dateTo != null) {
      final from = OdooDateTime.formatDateSlash(dateFrom);
      final to = OdooDateTime.formatDateSlash(dateTo);
      return from == to ? from : '$from → $to';
    }
    return OdooDateTime.formatDateSlash(dateFrom ?? dateTo);
  }
}
