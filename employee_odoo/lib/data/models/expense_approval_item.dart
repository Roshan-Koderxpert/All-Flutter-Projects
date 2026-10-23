/// One row in the expense approval lists, independent of how this Odoo
/// version models approvals.
///
/// Odoo 18 and earlier group expenses into an **expense report**
/// (`hr.expense.sheet`) and approve the report. Odoo 19 removed reports and
/// approves each **expense** (`hr.expense`) on its own. Both arrive here as
/// the same shape, and [model] records which one so the approve/refuse call
/// can be sent to the right place.
class ExpenseApprovalItem {
  const ExpenseApprovalItem({
    required this.id,
    required this.model,
    required this.title,
    required this.rawState,
    required this.stateLabel,
    required this.isPending,
    this.employeeId,
    this.employeeName = '',
    this.amount = 0,
    this.date,
    this.categoryName = '',
    this.lineCount,
  });

  final int id;

  /// `hr.expense.sheet` (Odoo <= 18) or `hr.expense` (Odoo 19+).
  final String model;

  final String title;

  /// The stored value, e.g. `submit` on a report or `submitted` on an expense.
  final String rawState;

  /// Odoo's own translated label for [rawState], read from the field's
  /// selection — so the badge always matches what the web client shows.
  final String stateLabel;

  /// Whether this row is waiting for an approver right now.
  final bool isPending;

  final int? employeeId;
  final String employeeName;
  final double amount;
  final DateTime? date;

  /// Only meaningful for a single expense.
  final String categoryName;

  /// Only meaningful for a report: how many expenses it groups.
  final int? lineCount;

  bool get isReport => model == 'hr.expense.sheet';

  /// Approved / posted / paid — anything past approval.
  bool get isSettled {
    const settled = {
      'approve', 'approved', 'post', 'posted', 'in_payment', 'paid', 'done',
    };
    return settled.contains(rawState);
  }

  bool get isRefused =>
      rawState == 'refuse' || rawState == 'refused' || rawState == 'cancel';
}
