import 'package:get/get.dart';
import '../../../data/models/expense_record.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/home_controller.dart';

enum ExpenseModuleStatus { loading, available, unavailable, noAccess, error }

class ExpenseController extends GetxController {
  late final ExpenseRepository _repo;

  final expenses = <ExpenseRecord>[].obs;
  final categories = <ExpenseCategory>[].obs;
  final isSubmitting = false.obs;
  final status = ExpenseModuleStatus.loading.obs;
  final lastError = ''.obs;
  final isCreatingReport = false.obs;

  /// False on Odoo 19, which has no expense-report model — the report actions
  /// are hidden there instead of failing with a 404.
  final supportsReports = true.obs;

  @override
  void onInit() {
    super.onInit();
    final client = Get.find<AuthController>().odooClient;
    _repo = ExpenseRepository(client!);
  }

  int? get _employeeId {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().employeeId.value;
    }
    return null;
  }

  Future<void> loadAll() async {
    final empId = _employeeId;
    if (empId == null) return;
    status.value = ExpenseModuleStatus.loading;
    try {
      final results = await Future.wait([
        _repo.fetchMine(empId),
        _repo.fetchCategories(),
      ]);
      expenses.value = results[0] as List<ExpenseRecord>;
      categories.value = results[1] as List<ExpenseCategory>;
      supportsReports.value = await _repo.supportsExpenseReports();
      status.value = ExpenseModuleStatus.available;
    } on ExpenseModuleUnavailable {
      status.value = ExpenseModuleStatus.unavailable;
    } on ExpenseAccessDenied {
      status.value = ExpenseModuleStatus.noAccess;
    } catch (e) {
      // Keep the real message: the screen shows it instead of a vague blank.
      lastError.value = e.toString();
      status.value = ExpenseModuleStatus.error;
    }
  }

  Future<bool> submitExpense({
    required int categoryId,
    required String description,
    required double amount,
    required DateTime date,
    bool paidByCompany = false,
    String? notes,
    List<int>? receiptBytes,
    String? receiptFileName,
    String? receiptMimeType,
  }) async {
    final empId = _employeeId;
    if (empId == null) return false;

    isSubmitting.value = true;
    lastError.value = '';
    try {
      final id = await _repo.createExpense(
        employeeId: empId,
        categoryId: categoryId,
        description: description,
        amount: amount,
        date: date,
        paidByCompany: paidByCompany,
        notes: notes,
        receiptBytes: receiptBytes,
        receiptFileName: receiptFileName,
        receiptMimeType: receiptMimeType,
      );
      if (id == null) return false;

      // Odoo creates the expense in draft. The app's Submit button means
      // "send this for approval", so move it straight on to the approver —
      // otherwise it sits in draft where nobody is waiting for it.
      final submitted = await _repo.submitExpense(
        expenseId: id,
        employeeId: empId,
        name: description,
      );
      await loadAll();
      if (!submitted) {
        // The expense exists; only the state change failed, so say exactly
        // that rather than reporting the whole submission as a failure.
        lastError.value =
            'Expense saved as draft, but it could not be sent for approval.';
      }
      return true;
    } catch (e) {
      // Temporary: print the real error so we can see what's actually failing
      // ignore: avoid_print
      print('submitExpense error: $e');
      lastError.value = e.toString();
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  double get toSubmitTotal => expenses
      .where((e) => e.rawState == 'draft' || e.rawState == 'reported')
      .fold(0.0, (sum, e) => sum + e.totalAmount);

  double get underValidationTotal => expenses
      .where((e) => e.rawState == 'submitted' || e.rawState == 'submit')
      .fold(0.0, (sum, e) => sum + e.totalAmount);

  double get toReimburseTotal => expenses
      .where((e) => e.rawState == 'approved')
      .fold(0.0, (sum, e) => sum + e.totalAmount);

  double get grandTotal => expenses.fold(0.0, (sum, e) => sum + e.totalAmount);

  /// Called from the detail screen's "Create Report" button — one expense at a time.
  Future<int?> createReportFromExpense(ExpenseRecord record) async {
    final empId = _employeeId;
    if (empId == null || record.totalAmount <= 0) return null;

    isCreatingReport.value = true;
    try {
      final id = await _repo.createReport(
        employeeId: empId,
        name: record.name,
        expenseIds: [record.id],
      );
      if (id != null) await loadAll();
      return id;
    } catch (e) {
      return null;
    } finally {
      isCreatingReport.value = false;
    }
  }
}