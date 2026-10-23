import 'package:field_service/app/core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/order_repository.dart';

class InvoiceView extends StatefulWidget {
  const InvoiceView({super.key});

  @override
  State<InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends State<InvoiceView> {
  final OrderRepository _repo = Get.find<OrderRepository>();

  Map<String, dynamic>? _invoice;
  int? _saleOrderId;
  bool _isLoadingList = false;
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  String _listError = '';
  bool _isConfirming = false;


  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _invoice = args?['invoice'] as Map<String, dynamic>?;
    _saleOrderId = args?['saleOrderId'] as int?;
    if (_invoice == null && _saleOrderId != null && _saleOrderId! > 0) {
      _loadInvoiceList();
    }
  }

  String _m2oLabel(dynamic v) {
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return '-';
  }

  String _currencySymbolFor(Map<String, dynamic>? record) {
    final s = record?['currency_symbol']?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
    return r'$';
  }

  String _fmtMoney(Map<String, dynamic>? currencySource, dynamic v) {
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    final sym = _currencySymbolFor(currencySource);
    final pos =
        (currencySource?['currency_position']?.toString() ?? 'before').toLowerCase();
    final amount = d.toStringAsFixed(2);
    if (pos == 'after') {
      return '$amount $sym';
    }
    return '$sym $amount';
  }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final dt = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (dt == null) return raw.toString();
    return DateFormat('MM/dd/yyyy').format(dt.toLocal());
  }

  Future<void> _onConfirm() async {
    final invoiceId = _invoice?['id'] as int?;
    if (invoiceId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.invoiceConfirmTitle,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Message ──
                Text(
                  AppStrings.invoiceConfirmMessage,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Confirm button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      AppStrings.invoiceConfirmButton,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirm != true || !mounted) return;

    setState(() => _isConfirming = true);
    final ok = await _repo.confirmInvoice(invoiceId);
    if (!mounted) return;
    setState(() => _isConfirming = false);

    final isOffline = !Get.find<ConnectivityService>().hasConnection;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (isOffline ? AppStrings.invoiceConfirmQueued : AppStrings.invoiceConfirmSuccess)
          : AppStrings.invoiceConfirmFailed),
      backgroundColor: ok
          ? (isOffline ? AppColors.stageInProgress : AppColors.success)
          : AppColors.error,
    ));
    if (ok) {
      final fresh = await _repo.fetchInvoiceById(invoiceId);
      if (!mounted) return;
      setState(() {
        if (fresh != null) _invoice = fresh;
      });
    }
  }

  Future<void> _loadInvoiceList() async {
    final saleOrderId = _saleOrderId;
    if (saleOrderId == null || saleOrderId <= 0) return;
    setState(() {
      _isLoadingList = true;
      _listError = '';
    });
    try {
      final list = await _repo.fetchInvoicesForSaleOrder(saleOrderId);
      if (!mounted) return;
      setState(() {
        _invoices = list;
        _isLoadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e.toString();
        _isLoadingList = false;
      });
    }
  }

  Future<void> _openInvoiceFromList(int invoiceId) async {
    final full = await _repo.fetchInvoiceById(invoiceId);
    if (!mounted) return;
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.invoiceLoadFailed),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _invoice = full;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invoice = _invoice;
    if (invoice == null) {
      return _buildInvoiceListScreen();
    }
    final state = invoice['state']?.toString() ?? 'draft';
    final isDraft = state == 'draft';
    final lines = (invoice['lines'] as List?)?.cast<Map>() ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 20,
        backgroundColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Fixed Header ──────────────────────────────
            Container(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: back + title
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          invoice['name']?.toString().isEmpty ?? true
                              ? 'Draft Invoice'
                              : invoice['name'].toString(),
                          style: AppTextStyles.h2.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: action buttons + status stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isDraft) ...[
                            _actionButton(
                              text: _isConfirming ? '' : 'Confirm',
                              isPrimary: true,
                              onPressed: _isConfirming ? null : _onConfirm,
                              isLoading: _isConfirming,
                            ),
                            const SizedBox(width: 8),
                            _actionButton(
                              text: 'Cancel',
                              isPrimary: false,
                              onPressed: () => Get.back(),
                            ),
                          ],
                        ],
                      ),
                      _buildStatusStepper(state),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Form Fields ───────────────────────
                    Container(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formRow(AppStrings.invoiceHeaderCustomer,
                              _m2oLabel(invoice['partner_id'])),
                          _formRow(AppStrings.invoiceHeaderDate,
                              _formatDate(invoice['invoice_date'])),
                          _formRow(AppStrings.invoiceHeaderPaymentTerms,
                              _m2oLabel(invoice['invoice_payment_term_id'])),
                          _formRow(
                              AppStrings.invoiceHeaderDeliveryDate,
                              _formatDate(invoice['delivery_date'] ??
                                  invoice['invoice_date_due'])),
                          _formRow(AppStrings.invoiceHeaderPaymentState,
                              invoice['payment_state']?.toString() ?? '-'),
                          _formRow(AppStrings.invoiceHeaderJournal,
                              _m2oLabel(invoice['journal_id'])),
                          _formRow(AppStrings.invoiceHeaderCompany,
                              _m2oLabel(invoice['company_id'])),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Invoice Lines Table ───────────────
                    Container(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.invoiceHeaderLines,
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInvoiceLinesTable(invoice, lines),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Totals ────────────────────────────
                    Container(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _totalRow(AppStrings.invoiceTotalUntaxed,
                              _fmtMoney(invoice, invoice['amount_untaxed'])),
                          const SizedBox(height: 6),
                          _totalRow(AppStrings.invoiceTotalLabel,
                              _fmtMoney(invoice, invoice['amount_total']),
                              isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceListScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 20,
        backgroundColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(AppStrings.invoiceListTitle,
                      style: AppTextStyles.h2.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadInvoiceList,
                    child: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingList
                  ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
                  : _listError.isNotEmpty
                  ? Center(child: Text(_listError))
                  : _invoices.isEmpty
                  ? const Center(child: Text(AppStrings.invoiceNoFound))
                  : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadInvoiceList,
                child: ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _invoices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final inv = _invoices[i];
                    final id = inv['id'] is int
                        ? inv['id'] as int
                        : int.tryParse('${inv['id']}');
                    final name =
                    (inv['name']?.toString().trim().isNotEmpty ?? false)
                        ? inv['name'].toString()
                        : AppStrings.invoiceDraft;
                    return GestureDetector(
                      onTap: id == null
                          ? null
                          : () => _openInvoiceFromList(id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: isDark
                              ? Border.all(color: AppColors.darkBorder)
                              : null,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: AppTextStyles.h3.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: ${_formatDate(inv['invoice_date'])}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary),
                                  ),
                                  Text(
                                    'Total: ${_fmtMoney(inv, inv['amount_total'])}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : Colors.black45),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required bool isPrimary,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isPrimary
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1)),
          side: BorderSide(
              color: isPrimary
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : const Color(0xFFF1F1F1))),
          foregroundColor: isPrimary
              ? AppColors.white
              : (isDark ? AppColors.darkTextPrimary : const Color(0xFF2B2A2A)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: isLoading
            ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isPrimary
                ? AppColors.white
                : (isDark ? AppColors.darkTextPrimary : const Color(0xFF2B2A2A)),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStepper(String state) {
    final isDraft = state == 'draft';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperChip(AppStrings.invoiceStepDraft, isActive: isDraft, isFirst: true),
        _stepperArrow(isDraft),
        _stepperChip(AppStrings.invoiceStepPosted, isActive: !isDraft, isFirst: false),
      ],
    );
  }

  Widget _stepperChip(String label,
      {required bool isActive, required bool isFirst}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg     = isDark ? const Color(0xFF2D2050) : const Color(0xFFEEEBF8);
    final inactiveBg   = isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1);
    final activeText   = isDark ? const Color(0xFF9B7EF4) : const Color(0xFF7B61C4);
    final inactiveText = isDark ? AppColors.darkTextSecondary : const Color(0xFF999999);
    final activeBorder   = isDark ? const Color(0xFF9B7EF4) : const Color(0xFF7B61C4);
    final inactiveBorder = isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isFirst ? 6 : 0),
          bottomLeft: Radius.circular(isFirst ? 6 : 0),
          topRight: Radius.circular(isFirst ? 0 : 6),
          bottomRight: Radius.circular(isFirst ? 0 : 6),
        ),
        border: Border.all(
          color: isActive ? activeBorder : inactiveBorder,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: isActive ? activeText : inactiveText,
        ),
      ),
    );
  }

  Widget _stepperArrow(bool leftActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 16,
      height: 28,
      color: leftActive
          ? (isDark ? const Color(0xFF2D2050) : const Color(0xFFEEEBF8))
          : (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1)),
      child: CustomPaint(painter: _ArrowPainter(leftActive, isDark: isDark)),
    );
  }

  Widget _formRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: AppColors.darkBorder) : null,
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              value.isEmpty || value == '-' ? '-' : value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceLinesTable(
    Map<String, dynamic> invoice,
    List<Map> lines,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg   = isDark ? AppColors.darkSurface3 : const Color(0xFFEDEDED);
    final headerText = isDark ? AppColors.darkTextPrimary : const Color(0xFF2B2A2A);
    final cellBg     = isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8);
    final cellText   = isDark ? AppColors.darkTextSecondary : const Color(0xFF484848);
    final divColor   = isDark ? AppColors.darkBorder : const Color(0xFFD8D8D8);

    Widget headerCell(String text, double width) => Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      color: headerBg,
      child: Text(text,
          style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600, color: headerText)),
    );

    Widget dataCell(String text, double width, {bool isProduct = false}) => Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      color: cellBg,
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: isProduct ? AppColors.primary : cellText,
          fontWeight: isProduct ? FontWeight.w500 : FontWeight.w400,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    Widget divider({double height = 48}) =>
        Container(width: 1, height: height, color: divColor);

    const double colProduct = 200;
    const double colQty     = 60;
    const double colUom     = 70;
    const double colPrice   = 75;
    const double colTax     = 70;
    const double colAmount  = 85;

    return Container(
      decoration: BoxDecoration(
        color: divColor,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                headerCell(AppStrings.invoiceColProduct, colProduct),
                divider(),
                headerCell(AppStrings.invoiceColQty, colQty),
                divider(),
                headerCell(AppStrings.invoiceColUom, colUom),
                divider(),
                headerCell(AppStrings.invoiceColPrice, colPrice),
                divider(),
                headerCell(AppStrings.invoiceColTaxes, colTax),
                divider(),
                headerCell(AppStrings.invoiceColAmount, colAmount),
              ],
            ),
            if (lines.isEmpty)
              Container(
                width: colProduct + colQty + colUom + colPrice + colTax + colAmount + 5,
                height: 52,
                color: cellBg,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(AppStrings.invoiceNoLines,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextDisabled
                            : AppColors.textDisabled)),
              )
            else
              ...lines.map((line) {
                final m = Map<String, dynamic>.from(line);
                final taxNames = (m['tax_ids'] as List?)
                    ?.map((t) =>
                t is Map ? t['name']?.toString() ?? '' : '')
                    .where((s) => s.isNotEmpty)
                    .join(', ') ??
                    '-';
                return Column(
                  children: [
                    Container(height: 1, color: divColor),
                    Row(
                      children: [
                        dataCell(_m2oLabel(m['product_id']), colProduct,
                            isProduct: true),
                        divider(height: 52),
                        dataCell(
                            (m['quantity'] as num?)?.toStringAsFixed(2) ?? '0',
                            colQty),
                        divider(height: 52),
                        dataCell(_m2oLabel(m['product_uom_id']), colUom),
                        divider(height: 52),
                        dataCell(
                            (m['price_unit'] as num?)?.toStringAsFixed(2) ?? '0',
                            colPrice),
                        divider(height: 52),
                        dataCell(taxNames, colTax),
                        divider(height: 52),
                        dataCell(
                            _fmtMoney(invoice, m['price_subtotal']), colAmount),
                      ],
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            )),
        const SizedBox(width: 16),
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            )),
      ],
    );
  }
}

// ── Arrow painter for stepper ─────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  final bool leftActive;
  final bool isDark;

  const _ArrowPainter(this.leftActive, {this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = leftActive
          ? (isDark ? const Color(0xFF9B7EF4) : const Color(0xFF7B61C4))
          : (isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.leftActive != leftActive || old.isDark != isDark;
}