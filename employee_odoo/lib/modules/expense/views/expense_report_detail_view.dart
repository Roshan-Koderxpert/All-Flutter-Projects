import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense_record.dart';
import '../../../data/models/expense_sheet.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/responsive.dart';

class ExpenseReportDetailView extends StatefulWidget {
  const ExpenseReportDetailView({super.key});

  @override
  State<ExpenseReportDetailView> createState() => _ExpenseReportDetailViewState();
}

class _ExpenseReportDetailViewState extends State<ExpenseReportDetailView> {
  ExpenseSheet? _sheet;
  bool _loading = true;
  bool _notFound = false;
  bool _submitting = false;
  late ExpenseRepository _repo;
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = Get.arguments as int?;
    if (id == null) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
      return;
    }
    final client = Get.find<AuthController>().odooClient;
    _repo = ExpenseRepository(client!);
    try {
      final sheet = await _repo.fetchSheetById(id);
      setState(() {
        _sheet = sheet;
        _notFound = sheet == null;
        _loading = false;
        if (sheet != null) _nameController.text = sheet.name;
      });
    } catch (e) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  Future<void> _submitToManager() async {
    if (_sheet == null) return;
    setState(() => _submitting = true);
    try {
      await _repo.submitSheetToManager(_sheet!.id);
      Get.snackbar('Submitted', 'Report sent to your manager for approval',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.brandBlue, colorText: Colors.white);
      await _load();
    } catch (e) {
      Get.snackbar('Failed', 'Could not submit report, please try again',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _resetToDraft() async {
    if (_sheet == null) return;
    setState(() => _submitting = true);
    try {
      await _repo.resetSheetToDraft(_sheet!.id);
      Get.snackbar('Reset', 'Report moved back to draft',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.brandBlue, colorText: Colors.white);
      await _load();
    } catch (e) {
      Get.snackbar('Failed', 'Could not reset report, please try again',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _updatePaymentMode(String mode) async {
    if (_sheet == null) return;
    final ok = await _repo.updatePaymentMode(_sheet!.id, mode);
    if (ok) await _load();
  }

  Future<void> _saveName() async {
    if (_sheet == null) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == _sheet!.name) return;
    final ok = await _repo.updateSheetFields(_sheet!.id, {'name': newName});
    if (ok) await _load();
  }

  Future<void> _pickEmployee() async {
    if (_sheet == null) return;
    final list = await _repo.fetchEmployeesForSelection();
    final selected = await _showPicker(list, _sheet!.employeeId);
    if (selected != null) {
      final ok = await _repo.updateSheetFields(_sheet!.id, {'employee_id': selected});
      if (ok) await _load();
    }
  }

  Future<void> _pickManager() async {
    if (_sheet == null) return;
    final list = await _repo.fetchManagersForSelection();
    final selected = await _showPicker(list, _sheet!.managerId);
    if (selected != null) {
      final ok = await _repo.updateSheetFields(_sheet!.id, {'user_id': selected});
      if (ok) await _load();
    }
  }

  Future<int?> _showPicker(List<Map<String, dynamic>> items, int? currentId) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final id = item['id'] as int;
              return ListTile(
                title: Text(item['name'] as String? ?? ''),
                trailing: id == currentId ? const Icon(Icons.check, color: AppColors.brandBlue) : null,
                onTap: () => Navigator.pop(context, id),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _editLine(ExpenseRecord line) async {
    final nameCtrl = TextEditingController(text: line.name);
    final amountCtrl = TextEditingController(text: line.totalAmount.toStringAsFixed(2));

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Wrap(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit Expense', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await _repo.deleteExpenseLine(line.id);
                          if (context.mounted) Navigator.pop(context, ok);
                        },
                        child: const Text('Remove'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlue),
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text.trim());
                          if (amount == null || amount <= 0) return;
                          final ok = await _repo.updateExpenseLine(line.id, {
                            'name': nameCtrl.text.trim(),
                            'price_unit': amount,
                            'total_amount_currency': amount,
                          });
                          if (context.mounted) Navigator.pop(context, ok);
                        },
                        child: const Text('Save', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Expense Report')),
      body: ResponsiveBody(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
          ? const Center(child: Text('This report could not be found.'))
          : _buildBody(_sheet!)),
    );
  }

  Widget _buildBody(ExpenseSheet sheet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusStepper(sheet.state),
          const SizedBox(height: 16),
          _buildSummaryCard(sheet),
          const SizedBox(height: 16),
          _buildLinesCard(sheet),
          const SizedBox(height: 16),
          _buildTotalsCard(sheet),
          const SizedBox(height: 20),
          if (sheet.state.isEditable) _buildSubmitButton(),
          if (sheet.state.canResetToDraft) _buildResetButton(),        ],
      ),
    );
  }

  Widget _buildStatusStepper(ExpenseSheetState state) {
    const steps = ['To Submit', 'Submitted', 'Approved', 'Posted', 'Done'];
    final current = state.stepIndex;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        itemBuilder: (context, i) {
          final isActive = i == current;
          final isPast = i < current;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.brandBlue : (isPast ? Colors.grey.shade200 : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? AppColors.brandBlue : Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: Text(
              steps[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(ExpenseSheet sheet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // new
          const Text('Expense Report Summary', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          sheet.state.isEditable
              ? TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
            onEditingComplete: () {
              _nameFocus.unfocus();
              _saveName();
            },
            onTapOutside: (_) {
              _nameFocus.unfocus();
              _saveName();
            },
          )
              : Text(sheet.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _editableInfoRow('Employee', sheet.employeeName, sheet.state.isEditable, _pickEmployee),
          _editableInfoRow('Manager', sheet.managerName ?? 'Not set', sheet.state.isEditable, _pickManager),
          const SizedBox(height: 8),
          // new — Paid By is always read-only, in every state
          const Text('Paid By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              sheet.paymentMode == 'company_account' ? 'Company' : 'Employee (to reimburse)',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text(value),
        ],
      ),
    );
  }

  Widget _editableInfoRow(String label, String value, bool editable, VoidCallback onTap) {
    return InkWell(
      onTap: editable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value)),
            if (editable) Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesCard(ExpenseSheet sheet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          // new
          ...sheet.lines.map((e) => InkWell(
            onTap: sheet.state.isEditable ? () => _editLine(e) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.categoryName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(e.name, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Text(e.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (sheet.state.isEditable) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                  ],
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(ExpenseSheet sheet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _totalRow('Untaxed Amount', sheet.untaxedAmount),
          _totalRow('Taxes', sheet.taxAmount),
          const Divider(),
          _totalRow('Total', sheet.totalAmount, bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
              color: bold ? AppColors.brandBlue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submitToManager,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _submitting
            ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Submit to Manager', style: TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _submitting ? null : _resetToDraft,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.brandBlue),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _submitting
            ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Reset to Draft', style: TextStyle(fontSize: 15)),
      ),
    );
  }
}