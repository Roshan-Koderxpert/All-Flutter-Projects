import 'dart:io';
import 'dart:typed_data';

import 'package:employee_odoo/modules/expense/views/pdf_preview_view.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense_record.dart';
import '../../../data/models/expense_sheet.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/expense_controller.dart';
import 'attachment_preview_view.dart';
import '../../../core/utils/responsive.dart';

class ExpenseDetailView extends StatefulWidget {
  const ExpenseDetailView({super.key});

  @override
  State<ExpenseDetailView> createState() => _ExpenseDetailViewState();
}

class _ExpenseDetailViewState extends State<ExpenseDetailView> {

  ExpenseRecord? _record;
  bool _loading = true;
  bool _notFound = false;

  List<ExpenseAttachment> _attachments = [];
  int? _downloadingId;
  late ExpenseRepository _repo;

  final Map<int, List<int>> _attachmentCache = {};
  bool _creatingReport = false;

  ExpenseSheet? _linkedSheet;
  bool _sheetLoading = false;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// False on Odoo 19, which has no expense-report model — the Create Report
  /// action is hidden there rather than failing with a 404.
  bool _supportsReports = true;

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
      final record = await _repo.fetchById(id);
      final attachments = record != null ? await _repo.fetchAttachments(id) : <ExpenseAttachment>[];
      final supportsReports = await _repo.supportsExpenseReports();
      setState(() {
        _record = record;
        _attachments = attachments;
        _supportsReports = supportsReports;
        _notFound = record == null;
        _loading = false;
      });

      if (record != null && record.sheetId != null) {
        setState(() => _sheetLoading = true);
        final sheet = await _repo.fetchSheetById(record.sheetId!);
        setState(() {
          _linkedSheet = sheet;
          _sheetLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  Future<List<int>?> _getBytes(ExpenseAttachment a) async {
    List<int>? bytes = _attachmentCache[a.id];
    if (bytes == null) {
      bytes = await _repo.downloadAttachment(a.id);
      if (bytes == null) {
        Get.snackbar('Failed', 'Could not load this file', snackPosition: SnackPosition.BOTTOM);
        return null;
      }
      _attachmentCache[a.id] = bytes;
    }
    return bytes;
  }

  Future<void> _handlePreview(ExpenseAttachment a) async {
    setState(() => _downloadingId = a.id);
    try {
      final bytes = await _getBytes(a);
      if (bytes == null) return;

      if (a.mimetype.startsWith('image/')) {
        Get.to(() => AttachmentPreviewView(imageBytes: bytes, fileName: a.name));
      } else if (a.mimetype.contains('pdf')) {
        Get.to(() => PdfPreviewView(pdfBytes: bytes, fileName: a.name));
      } else {
        // No inline viewer for this file type — fall back to external app.
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${a.name}');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      }
    } finally {
      setState(() => _downloadingId = null);
    }
  }

  Future<void> _handleDownload(ExpenseAttachment a) async {
    setState(() => _downloadingId = a.id);
    try {
      final bytes = await _getBytes(a);
      if (bytes == null) return;

      final ext = a.name.contains('.') ? a.name.split('.').last : 'dat';
      final baseName = a.name.contains('.')
          ? a.name.substring(0, a.name.lastIndexOf('.'))
          : a.name;

      await FileSaver.instance.saveFile(
        name: baseName,
        bytes: Uint8List.fromList(bytes),
        fileExtension: ext,
        mimeType: MimeType.other,
      );

      Get.snackbar('Downloaded', '${a.name} saved to your device',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Failed', 'Could not save this file', snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _downloadingId = null);
    }
  }

  Future<void> _createReport(ExpenseRecord r) async {
    if (r.totalAmount <= 0) {
      Get.snackbar('Missing amount', 'Add an amount before creating a report',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _creatingReport = true);
    try {
      final controller = Get.find<ExpenseController>();
      final sheetId = await controller.createReportFromExpense(r);
      if (sheetId != null) {
        Get.offNamed(AppRoutes.expenseReportDetail, arguments: sheetId);
      } else {
        Get.snackbar('Failed', 'Could not create report, please try again',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _creatingReport = false);
    }
  }

  Future<void> _submitLinkedSheetToManager() async {
    if (_linkedSheet == null) return;
    setState(() => _actionInProgress = true);
    try {
      await _repo.submitSheetToManager(_linkedSheet!.id);
      Get.snackbar('Submitted', 'Report sent to your manager for approval',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.brandBlue, colorText: Colors.white);
      await _load();
    } catch (e) {
      Get.snackbar('Failed', 'Could not submit report, please try again',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _actionInProgress = false);
    }
  }

  Future<void> _resetLinkedSheetToDraft() async {
    if (_linkedSheet == null) return;
    setState(() => _actionInProgress = true);
    try {
      await _repo.resetSheetToDraft(_linkedSheet!.id);
      Get.snackbar('Reset', 'Report moved back to draft',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.brandBlue, colorText: Colors.white);
      await _load();
    } catch (e) {
      Get.snackbar('Failed', 'Could not reset report, please try again',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _actionInProgress = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Detail')),
      body: ResponsiveBody(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
          ? const Center(child: Text('This expense could not be found.'))
          : _buildDetail(_record!)),
    );
  }

  Widget _buildDetail(ExpenseRecord r) {
    final stateColor = switch (r.state) {
      ExpenseState.approved => Colors.green,
      ExpenseState.refused => Colors.red,
      ExpenseState.done => AppColors.brandBlue,
      _ => Colors.orange,
    };
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.displayState,
                    style: TextStyle(color: stateColor, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _row(Icons.category_outlined, 'Category', r.categoryName),
          _row(Icons.attach_money, 'Amount', r.totalAmount.toStringAsFixed(2)),
          _row(Icons.event_outlined, 'Date',
              '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}'),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ..._attachments.map((a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  a.mimetype.contains('pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  color: AppColors.brandBlue,
                ),
                title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: _downloadingId == a.id
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: 'Preview',
                      onPressed: () => _handlePreview(a),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Download',
                      onPressed: () => _handleDownload(a),
                    ),
                  ],
                ),
              ),
            )),
          ],
          // new
          if (r.employeeName != null) _row(Icons.person_outline, 'Employee', r.employeeName!),

          const SizedBox(height: 28),
          if (_sheetLoading)
            const Center(child: CircularProgressIndicator())
          else if (r.sheetId == null && _supportsReports) ...[
            // Not reported yet — offer to create the report.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (r.totalAmount > 0 && !_creatingReport)
                    ? () => _createReport(r)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _creatingReport
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Report', style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
          ] else if (_linkedSheet != null) ...[
            // Already grouped into a report — offer the action matching its current state.
            if (_linkedSheet!.state.isEditable)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _actionInProgress ? null : _submitLinkedSheetToManager,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _actionInProgress
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit to Manager', style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              )
            else if (_linkedSheet!.state.canResetToDraft)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionInProgress ? null : _resetLinkedSheetToDraft,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brandBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _actionInProgress
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Reset to Draft', style: TextStyle(fontSize: 15)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }
}


