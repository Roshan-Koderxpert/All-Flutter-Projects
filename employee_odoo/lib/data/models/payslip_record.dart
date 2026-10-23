enum PayslipState { draft, verify, done, paid, cancel }

PayslipState _parseState(dynamic value) {
  switch (value) {
    case 'draft':
      return PayslipState.draft;
    case 'verify':
      return PayslipState.verify;
    case 'done':
      return PayslipState.done;
    case 'paid':
      return PayslipState.paid;
    case 'cancel':
      return PayslipState.cancel;
    default:
      return PayslipState.draft;
  }
}

extension PayslipStateX on PayslipState {
  String get label {
    switch (this) {
      case PayslipState.draft:
        return 'Draft';
      case PayslipState.verify:
        return 'Waiting';
      case PayslipState.done:
        return 'Validated';
      case PayslipState.paid:
        return 'Paid';
      case PayslipState.cancel:
        return 'Cancelled';
    }
  }
}

class PayslipRecord {
  final int id;
  final String name;
  final String? number;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final PayslipState state;
  final String? structureName;
  final double? netWage;
  final String? employeeName;

  PayslipRecord({
    required this.id,
    required this.name,
    this.number,
    this.dateFrom,
    this.dateTo,
    required this.state,
    this.structureName,
    this.netWage,
    this.employeeName,
  });

  factory PayslipRecord.fromOdoo(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic v) => (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

    return PayslipRecord(
      id: row['id'] as int,
      name: row['name'] is String ? row['name'] as String : '',
      number: row['number'] is String ? row['number'] as String : null,
      dateFrom: parseDate(row['date_from']),
      dateTo: parseDate(row['date_to']),
      state: _parseState(row['state']),
      structureName: (row['struct_id'] is List) ? row['struct_id'][1] as String : null,
      netWage: (row['net_wage'] is num) ? (row['net_wage'] as num).toDouble() : null,
      employeeName: (row['employee_id'] is List) ? row['employee_id'][1] as String : null,
    );
  }
}