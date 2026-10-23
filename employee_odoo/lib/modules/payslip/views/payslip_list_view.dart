import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/models/payslip_record.dart';
import '../../expense/views/pdf_preview_view.dart';
import '../controllers/payslip_controller.dart';
import '../../../core/utils/responsive.dart';

class PayslipListView extends GetView<PayslipController> {
  const PayslipListView({super.key});

  @override
  Widget build(BuildContext context) {
    controller.loadAll();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'Payslips'),
      body: ResponsiveBody(child: Obx(() {
        switch (controller.status.value) {
          case PayslipModuleStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
          case PayslipModuleStatus.unavailable:
            return _buildUnavailable();
          case PayslipModuleStatus.noEmployee:
            return _buildNoEmployee();
          case PayslipModuleStatus.error:
            return _buildError();
          case PayslipModuleStatus.available:
            return Column(
              children: [
                if (controller.isViewingAll.value) _buildAllEmployeesBanner(),
                Expanded(child: _buildList()),
              ],
            );
        }
      })),
    );
  }

  Widget _buildAllEmployeesBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.brandBlue),
          const SizedBox(width: 8),
          Text(
            'Showing validated payslips for all employees',
            style: AppTextStyles.style(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.brandBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Obx(() {
      if (controller.payslips.isEmpty) return const _EmptyState();
      return RefreshIndicator(
        color: AppColors.brandBlue,
        onRefresh: controller.loadAll,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: controller.payslips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _PayslipCard(payslip: controller.payslips[index]),
        ),
      );
    });
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Payslips aren\'t available', style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your organization hasn\'t enabled the Payroll app on this Odoo server.',
              style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
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
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Something went wrong loading your payslips.', style: AppTextStyles.style(fontSize: 13.5)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: controller.loadAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEmployee() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No employee record found',
              style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your Odoo user account isn\'t linked to an employee record, so payslips can\'t be matched to you. Ask your administrator to link your user to an Employee in Odoo.',
              style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: controller.loadAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No payslips yet', style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Validated payslips will appear here once processed by HR.',
              style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.payslip});

  final PayslipRecord payslip;

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get _period {
    if (payslip.dateFrom == null || payslip.dateTo == null) return payslip.name;
    return '${_formatDate(payslip.dateFrom)} - ${_formatDate(payslip.dateTo)}';
  }

  Color _stateColor() {
    switch (payslip.state) {
      case PayslipState.paid:
        return const Color(0xFF22C55E);
      case PayslipState.done:
        return AppColors.brandBlue;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _openPreview(BuildContext context) async {
    final controller = Get.find<PayslipController>();
    final bytes = await controller.previewPayslip(payslip);
    if (bytes == null) return;
    Get.to(() => PdfPreviewView(pdfBytes: bytes, fileName: payslip.name));
  }

  Future<void> _download(BuildContext context) async {
    final controller = Get.find<PayslipController>();
    final bytes = await controller.downloadPayslip(payslip);
    if (bytes == null) return;

    // Payslip numbers often look like "SLIP/2026/07/0001" — the slashes
    // would otherwise be read as path separators and silently relocate
    // the file into nested folders instead of a flat file in Downloads.
    final rawName = payslip.number ?? payslip.name;
    final safeName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();

    try {
      // saveFile() writes to the app's private sandbox on Android — never
      // visible in the Downloads app or any file manager. saveAs() opens
      // the native "Save As" picker so the user chooses the destination
      // (Downloads by default), which is then properly registered and
      // visible afterward.
      final savedPath = await FileSaver.instance.saveAs(
        name: safeName,
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (savedPath == null) return; // user cancelled the save dialog

      Get.snackbar(
        'Downloaded',
        'Payslip saved successfully',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar('Failed', 'Could not save this file', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = Get.find<PayslipController>();
      final isDownloading = controller.downloadingId.value == payslip.id;
      final isPreviewing = controller.previewingId.value == payslip.id;
      final isBusy = isDownloading || isPreviewing;

      return Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isBusy ? null : () => _openPreview(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandBlue.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.brandBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payslip.name,
                        style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (payslip.employeeName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          payslip.employeeName!,
                          style: AppTextStyles.style(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.brandBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _period,
                        style: AppTextStyles.style(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _stateColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              payslip.state.label,
                              style: AppTextStyles.style(fontSize: 10.5, fontWeight: FontWeight.w600, color: _stateColor()),
                            ),
                          ),
                          if (payslip.netWage != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Net: ${payslip.netWage!.toStringAsFixed(2)}',
                              style: AppTextStyles.style(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isPreviewing ? null : () => _openPreview(context),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: isPreviewing
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandBlue),
                      )
                          : const Icon(Icons.visibility_outlined, size: 19, color: AppColors.brandBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isDownloading ? null : () => _download(context),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: isDownloading
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandBlue),
                      )
                          : const Icon(Icons.download_rounded, size: 19, color: AppColors.brandBlue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}