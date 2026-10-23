import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense_record.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/expense_controller.dart';
import '../widgets/submit_expense_sheet.dart';
import '../../../core/utils/responsive.dart';

class ExpenseListView extends GetView<ExpenseController> {
  const ExpenseListView({super.key});

  @override
  Widget build(BuildContext context) {
    controller.loadAll();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Expenses')),
      body: ResponsiveBody(child: Obx(() {
        switch (controller.status.value) {
          case ExpenseModuleStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case ExpenseModuleStatus.unavailable:
            return _buildUnavailable();
          case ExpenseModuleStatus.noAccess:
            return _buildNoAccess();
          case ExpenseModuleStatus.error:
            return _buildError();
          case ExpenseModuleStatus.available:
            return RefreshIndicator(
              onRefresh: controller.loadAll,
              child: Column(
                children: [
                  _buildSummaryRow(),
                  Expanded(child: _buildList()),
                ],
              ),
            );
        }
      })),
      bottomNavigationBar: Obx(() {
        if (controller.status.value != ExpenseModuleStatus.available) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            // White footer stays full-bleed; its contents line up with the
            // width-capped list above.
            child: ResponsiveBody(
              child: Obx(() {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(controller.grandTotal.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.brandBlue)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => SubmitExpenseSheet.show(),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('New Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              );
            }),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummaryRow() {
    return Obx(() => Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _summaryTile('To Submit', controller.toSubmitTotal, Colors.blueGrey),
          _verticalDivider(),
          _summaryTile('Under Validation', controller.underValidationTotal, Colors.orange),
          _verticalDivider(),
          _summaryTile('To Be Reimbursed', controller.toReimburseTotal, Colors.green),
        ],
      ),
    ));
  }

  Widget _verticalDivider() => Container(width: 1, height: 40, color: Colors.grey.shade200);

  Widget _summaryTile(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            amount.toStringAsFixed(0),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Expenses aren\'t available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The Expenses app is not installed on the database you are signed '
                  'in to$_databaseSuffix. Ask your admin to install it, or sign in '
                  'to the database where Expenses is enabled.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => controller.loadAll(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// The database the app is actually talking to — the fastest way to spot a
  /// server with several databases where only one has Expenses installed.
  String get _databaseSuffix {
    if (!Get.isRegistered<AuthController>()) return '';
    final db = Get.find<AuthController>().selectedDatabase.value;
    return db.isEmpty ? '' : ' (\u201c$db\u201d)';
  }

  Widget _buildNoAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'You don\'t have access to Expenses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your Odoo account is not allowed to read expense records. Ask '
                  'your admin to give you Expenses access.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => controller.loadAll(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Something went wrong loading your expenses.'),
            if (controller.lastError.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                controller.lastError.value,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => controller.loadAll(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Obx(() {
      if (controller.expenses.isEmpty) {
        return ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No expenses submitted yet.')),
          ],
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: controller.expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final e = controller.expenses[index];
          return _buildExpenseCard(e);
        },
      );
    });
  }

// new signature
  Widget _buildExpenseCard(ExpenseRecord e) {
    final stateColor = switch (e.state) {
      ExpenseState.approved => Colors.green,
      ExpenseState.refused => Colors.red,
      ExpenseState.done => AppColors.brandBlue,
      ExpenseState.submitted => Colors.orange,
      _ => Colors.blueGrey,
    };
    final dateLabel = '${e.date.day.toString().padLeft(2, '0')}/'
        '${e.date.month.toString().padLeft(2, '0')}/${e.date.year}';
    // new
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(AppRoutes.expenseDetail, arguments: e.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandOrange.withOpacity(0.12),
                child: const Icon(Icons.receipt_outlined, color: AppColors.brandOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$dateLabel  ·  ${e.categoryName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(e.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: stateColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(e.displayState, style: TextStyle(fontSize: 11, color: stateColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}