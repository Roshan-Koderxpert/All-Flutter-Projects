enum ExpenseState {
  draft,
  reported,
  submitted,
  approved,
  // Odoo 19 continues past approval on the expense itself.
  posted,
  inPayment,
  paid,
  refused,
  done,
}


extension ExpenseStateX on ExpenseState {
  String get label {
    switch (this) {
      case ExpenseState.draft:
        return 'To Report';
      case ExpenseState.reported:
        return 'To Submit';
      case ExpenseState.submitted:
        return 'Submitted';
      case ExpenseState.approved:
        return 'Approved';
      case ExpenseState.posted:
        return 'Posted';
      case ExpenseState.inPayment:
        return 'In Payment';
      case ExpenseState.paid:
        return 'Paid';
      case ExpenseState.refused:
        return 'Refused';
      case ExpenseState.done:
        return 'Paid';
    }
  }
}

ExpenseState mapExpenseState(String odooState) {
  switch (odooState) {
    case 'draft':
      return ExpenseState.draft;
    case 'reported':
      return ExpenseState.reported;
    case 'submitted':
    case 'submit':
      return ExpenseState.submitted;
    case 'approved':
      return ExpenseState.approved;
    case 'posted':
      return ExpenseState.posted;
    case 'in_payment':
      return ExpenseState.inPayment;
    case 'paid':
      return ExpenseState.paid;
    case 'refused':
      return ExpenseState.refused;
    case 'done':
      return ExpenseState.done;
    default:
      return ExpenseState.draft;
  }
}

class ExpenseCategory {
  final int id;
  final String name;

  ExpenseCategory({required this.id, required this.name});
}

class ExpenseRecord {
  final int id;
  final String name;
  final int? categoryId;
  final String categoryName;
  final double unitAmount;
  final double totalAmount;
  final DateTime date;
  final ExpenseState state;
  final String rawState;

  /// Odoo's own translated label for [rawState], read from the `state` field's
  /// selection on the connected database. Empty when it couldn't be read.
  final String stateLabel;
  final String? employeeName;
  final int? sheetId;

  ExpenseRecord({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unitAmount,
    required this.totalAmount,
    required this.date,
    required this.state,
    required this.rawState,
    this.stateLabel = '',
    required this.sheetId,
    this.employeeName,
  });

  /// The expense-report link, under whichever name this Odoo version uses.
  /// `sheet_id` through Odoo 18; Odoo 19 dropped it.
  static int? _sheetId(Map<String, dynamic> row) {
    for (final key in const ['sheet_id', 'expense_sheet_id', 'report_id']) {
      final value = row[key];
      if (value is List && value.isNotEmpty && value.first is int) {
        return value.first as int;
      }
    }
    return null;
  }

  /// [stateLabels] comes from the database's own `state` selection, so the
  /// status shown always matches the Odoo version and language in use rather
  /// than a label hard-coded in the app.
  /// What to show the user: the server's label when known, otherwise the
  /// app's built-in name for that state.
  String get displayState => stateLabel.isNotEmpty ? stateLabel : state.label;

  factory ExpenseRecord.fromOdoo(
    Map<String, dynamic> row, {
    Map<String, String> stateLabels = const {},
  }) {
    final raw = row['state'] is String ? row['state'] as String : 'draft';
    return ExpenseRecord(
      id: row['id'] as int,
      name: row['name'] is String ? row['name'] as String : '',
      categoryId: (row['product_id'] is List) ? row['product_id'][0] as int : null,
      categoryName: (row['product_id'] is List) ? row['product_id'][1] as String : '',
      unitAmount: (row['price_unit'] as num?)?.toDouble() ?? 0,
      totalAmount: (row['total_amount_currency'] as num?)?.toDouble()
          ?? (row['total_amount'] as num?)?.toDouble()
          ?? 0,
      date: row['date'] is String
          ? DateTime.tryParse(row['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      state: mapExpenseState(raw),
      rawState: raw,
      stateLabel: stateLabels[raw] ?? '',
      employeeName: (row['employee_id'] is List) ? row['employee_id'][1] as String : null,
      sheetId: _sheetId(row),

    );
  }
}