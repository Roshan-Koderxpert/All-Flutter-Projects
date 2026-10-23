import 'expense_record.dart';

enum ExpenseSheetState { draft, submit, approve, post, done, cancel }

extension ExpenseSheetStateX on ExpenseSheetState {
  String get label {
    switch (this) {
      case ExpenseSheetState.draft:
        return 'To Submit';
      case ExpenseSheetState.submit:
        return 'Submitted';
      case ExpenseSheetState.approve:
        return 'Approved';
      case ExpenseSheetState.post:
        return 'Posted';
      case ExpenseSheetState.done:
        return 'Done';
      case ExpenseSheetState.cancel:
        return 'Cancelled';
    }
  }

  bool get isEditable => this == ExpenseSheetState.draft;

  /// Reset to Draft is only allowed between Submitted and Approved —
  /// once Posted/Done it's locked, matching Odoo's own rule.
  bool get canResetToDraft =>
      this == ExpenseSheetState.submit || this == ExpenseSheetState.approve;

  int get stepIndex {
    switch (this) {
      case ExpenseSheetState.draft:
        return 0;
      case ExpenseSheetState.submit:
        return 1;
      case ExpenseSheetState.approve:
        return 2;
      case ExpenseSheetState.post:
        return 3;
      case ExpenseSheetState.done:
        return 4;
      case ExpenseSheetState.cancel:
        return -1;
    }
  }
}

ExpenseSheetState mapExpenseSheetState(String odooState) {
  switch (odooState) {
    case 'draft':
      return ExpenseSheetState.draft;
    case 'submit':
      return ExpenseSheetState.submit;
    case 'approve':
      return ExpenseSheetState.approve;
    case 'post':
      return ExpenseSheetState.post;
    case 'done':
      return ExpenseSheetState.done;
    case 'cancel':
      return ExpenseSheetState.cancel;
    default:
      return ExpenseSheetState.draft;
  }
}

class ExpenseSheet {
  final int id;
  final String name;
  final String employeeName;
  final int? employeeId;
  final String? managerName;
  final int? managerId;
  final String paymentMode; // 'own_account' or 'company_account'
  final ExpenseSheetState state;
  final double untaxedAmount;
  final double taxAmount;
  final double totalAmount;
  final List<ExpenseRecord> lines;

  ExpenseSheet({
    required this.id,
    required this.name,
    required this.employeeName,
    required this.employeeId,
    required this.managerName,
    required this.managerId,
    required this.paymentMode,
    required this.state,
    required this.untaxedAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.lines,
  });

  factory ExpenseSheet.fromOdoo(Map<String, dynamic> row, List<ExpenseRecord> lines) {
    final total = (row['total_amount'] as num?)?.toDouble() ?? 0;
    final untaxed = (row['untaxed_amount'] as num?)?.toDouble() ?? total;
    return ExpenseSheet(
      id: row['id'] as int,
      name: row['name'] is String ? row['name'] as String : '',
      employeeName: (row['employee_id'] is List) ? row['employee_id'][1] as String : '',
      employeeId: (row['employee_id'] is List) ? row['employee_id'][0] as int : null,
      managerName: (row['user_id'] is List) ? row['user_id'][1] as String : null,
      managerId: (row['user_id'] is List) ? row['user_id'][0] as int : null,
      paymentMode: row['payment_mode'] is String ? row['payment_mode'] as String : 'own_account',
      state: mapExpenseSheetState(row['state'] is String ? row['state'] as String : 'draft'),
      untaxedAmount: untaxed,
      taxAmount: (total - untaxed).clamp(0, double.infinity),
      totalAmount: total,
      lines: lines,
    );
  }
}