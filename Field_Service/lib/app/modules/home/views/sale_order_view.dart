import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/assets.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/chatter.dart';
import '../../../data/repositories/order_repository.dart';
import 'delivery_view.dart';
import 'invoice_view.dart';

class SaleOrderView extends StatefulWidget {
  const SaleOrderView({super.key});

  @override
  State<SaleOrderView> createState() => _SaleOrderViewState();
}

class _SaleOrderViewState extends State<SaleOrderView> {
  final OrderRepository _repository = Get.find<OrderRepository>();

  Map<String, dynamic>? _saleOrder;
  bool _isLoading = true;
  String _error = '';
  late final int? _fsmOrderId;
  late final int? _partnerId;
  String _selectedTab = 'Order Lines';
  bool _invoiceConfirmed = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _fsmOrderId = args?['fsmOrderId'] as int?;
    _partnerId  = args?['partnerId']  as int?;

// If we already have the data passed directly, use it
    final passedData = args?['saleOrderData'] as Map<String, dynamic>?;
    if (passedData != null && passedData['queued_offline'] == true) {
      // Offline-queued local sale order — show directly, no fetch needed
      _saleOrder = passedData;
      _isLoading = false;
      final invoiceStatus = passedData['invoice_status']?.toString() ?? '';
      _invoiceConfirmed = invoiceStatus == 'invoiced';
    } else if (passedData != null && (passedData['lines'] as List?)?.isNotEmpty == true) {
      // Data passed directly with lines — use it immediately
      _saleOrder = passedData;
      _isLoading = false;
      final invoiceStatus = passedData['invoice_status']?.toString() ?? '';
      _invoiceConfirmed = invoiceStatus == 'invoiced';
    } else if (passedData != null && passedData['id'] != null) {
      // Data passed but lines may be empty — re-fetch by id to get fresh lines
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final fresh = await _repository.fetchSaleOrderById(passedData['id'] as int);
        if (mounted) {
          setState(() {
            _saleOrder = fresh ?? passedData;
            _isLoading = false;
            if (_saleOrder == null) _error = 'Could not load sale order.';
          });
        }
      });
    } else {
      _loadSaleOrder();
    }
  }

  Future<void> _loadSaleOrder() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      Map<String, dynamic>? data;
      if (_fsmOrderId != null) {
        data = await _repository.fetchSaleOrderForFsmOrder(_fsmOrderId!);
      }
      if (!mounted) return;
      setState(() {
        _saleOrder = data;
        _isLoading = false;
        if (data == null) _error = 'No sale order found for this FSM order.';
        final invoiceStatus = data?['invoice_status']?.toString() ?? '';
        _invoiceConfirmed = invoiceStatus == 'invoiced';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _m2oLabel(dynamic v) {
    if (v == null || v == false) return '';
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return v.toString();
  }

  /// Payment terms: standard `payment_term_id` or `invoice_payment_term_id` (Odoo variants).
  String _paymentTermsLabel(Map<String, dynamic> order) {
    for (final key in ['payment_term_id', 'invoice_payment_term_id']) {
      final v = order[key];
      if (v == null || v == false) continue;
      final s = _m2oLabel(v);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// Service location from sale order FSM/shipping fields or FSM order location (repo).
  String _serviceLocationLabel(Map<String, dynamic> order) {
    for (final key in [
      'fsm_location_id',
      'service_location_id',
      'partner_shipping_id',
      'fsm_service_location_id',
    ]) {
      final s = _m2oLabel(order[key]);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _quotationTemplateLabel(Map<String, dynamic> order) {
    final v = order['sale_order_template_id'];
    if (v == null || v == false) return '';
    return _m2oLabel(v);
  }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final s = raw.toString();
    final dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (dt == null) return s;
    return DateFormat('MM/dd/yyyy HH:mm:ss').format(dt.toLocal());
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

  String _fmtQty(dynamic v) {
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    if (d == d.roundToDouble()) return d.toStringAsFixed(0);
    return d.toStringAsFixed(2);
  }

  String _stateLabel(dynamic state) {
    switch (state?.toString()) {
      case 'draft': return 'Quotation';
      case 'sent':  return 'Quotation Sent';
      case 'sale':  return 'Sales Order';
      case 'done':  return 'Locked';
      case 'cancel':return 'Cancelled';
      default:      return state?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error.isNotEmpty
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSaleOrder,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final order = _saleOrder!;
    final state = order['state']?.toString() ?? 'draft';
    final lines = (order['lines'] as List?)?.cast<Map>() ?? [];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(order, state)),
        SliverToBoxAdapter(child: _buildInfoSection(order)),
        SliverToBoxAdapter(child: _buildOrderLinesSection(order, lines)),
        SliverToBoxAdapter(child: _buildTotalsSection(order)),
        SliverToBoxAdapter(child: _buildChatterSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Header: back + name + action buttons + status stepper ─────────────────
  Widget _buildHeader(Map<String, dynamic> order, String state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Red top bar with name + badges
        Container(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Image.asset(AppImage.back,
                  height: 25, width: 25,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,),
              ),
              const SizedBox(width: 8),
              Text(
                (order['queued_offline'] == true
                    ? 'Pending Sale Order (Offline)'
                    : order['name']?.toString() ?? 'Sale Order'),
                style: AppTextStyles.h2.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Action buttons + icon row
        Container(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              // Invoice + Email chips
              // Replace this entire GestureDetector block for Create Invoice button:
              if (!_invoiceConfirmed)
                GestureDetector(
                  onTap: () {
                    if (_saleOrder?['queued_offline'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sale order is queued offline. Connect to internet to create invoice.'),
                          backgroundColor: AppColors.stageInProgress,
                        ),
                      );
                      return;
                    }
                    if (_isDeliveryValidated()) {
                      _onCreateInvoiceTapped();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please validate the delivery first before creating an invoice.'),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isDeliveryValidated() ? AppColors.primary : const Color(0xFFCCCCCC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Create Invoice',
                      style: TextStyle(
                        color: _isDeliveryValidated() ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Spacer(),
              // Small icon buttons
              _flashDropdownBtn(),
              const SizedBox(width: 6),
              _moreDropdownBtn(),

            ],
          ),
        ),
      ],
    );
  }



  Widget _badgedHeaderIcon(String iconPath, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Image.asset(iconPath,  height: 22, width: 22,),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF3333),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _headerActionChip(String label,
      {bool isPrimary = false, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
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

  Widget _flashDropdownBtn() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      color: isDark ? AppColors.darkSurface2 : AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'delivery',
          child: Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Text('Delivery',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600,color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'invoices',
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Text('Invoices',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600,color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ],
          ),
        ),
      ],
      onSelected: (v) {
        if (v == 'delivery') _openDeliveries();
        if (v == 'invoices') _openInvoicesList();
      },
      child: Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Image.asset(
            AppImage.smartbutton,
            height: 22,
            width: 22,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _moreDropdownBtn() {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = _saleOrder?['state']?.toString() ?? 'sale';
    final steps = [
      {'value': 'draft', 'label': 'Quotation'},
      {'value': 'sent',  'label': 'Quotation Sent'},
      {'value': 'sale',  'label': 'Sales Order'},
    ];

    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      color: isDark ? AppColors.darkSurface2 : AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      enabled: true,
      onSelected: (_) {},
      itemBuilder: (_) => steps.map((step) {
        final isActive = step['value'] == state;
        return PopupMenuItem<String>(
          value: step['value'],
          enabled: false,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: isActive ? AppColors.primary : AppColors.darkTextDisabled,
              ),
              const SizedBox(width: 10),
              Text(
                step['label']!,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Image.asset(
            AppImage.more,
            height: 22,
            width: 22,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }


  Widget _smallIconBtn(String iconPath) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 33,
      height: 33,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Image.asset(
          iconPath,
          height: 22,
          width: 22,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildStatusStepper(String state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = ['Quotation', 'Quotation Sent', 'Sales Order'];
    final stateMap = {'draft': 0, 'sent': 1, 'sale': 2, 'done': 2};
    final currentIdx = stateMap[state] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final idx = e.key;
          final label = e.value;
          final isActive = idx == currentIdx;
          final isPast = idx < currentIdx;
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.textPrimary
                    : isPast
                    ? (isDark ? AppColors.darkSurface2 : const Color(0xFFF0F0F0))
                    : (isDark ? AppColors.darkSurface : AppColors.white),
                borderRadius: idx == 0
                    ? const BorderRadius.horizontal(left: Radius.circular(7))
                    : idx == steps.length - 1
                    ? const BorderRadius.horizontal(right: Radius.circular(7))
                    : BorderRadius.zero,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppColors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Info section: Customer, Order Date, Payment Terms, Service Location ───
  Widget _buildInfoSection(Map<String, dynamic> order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldBox('Customer',
              _m2oLabel(order['partner_id'])),
          const SizedBox(height: 12),
          _fieldBox('Order Date',
              _formatDate(order['date_order'])),
          const SizedBox(height: 12),
          _fieldBox('Service Location', _serviceLocationLabel(order),
              blankIfEmpty: true),
          const SizedBox(height: 12),
          _fieldBox('Payment Terms', _paymentTermsLabel(order),
              blankIfEmpty: true),
          const SizedBox(height: 12),
          _fieldBox('Quotation Template', _quotationTemplateLabel(order),
              blankIfEmpty: true),
        ],
      ),
    );
  }

  Widget _fieldBox(String label, String value, {bool blankIfEmpty = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display = value.isEmpty
        ? (blankIfEmpty ? '' : '-')
        : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.h3.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
            display,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: value.isEmpty
                  ? (isDark ? AppColors.darkTextDisabled : AppColors.textDisabled)
                  : AppColors.info,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  bool _isDeliveryValidated() {
    final deliveryStatus = _saleOrder?['delivery_status']?.toString() ?? '';
    return deliveryStatus == 'full' || deliveryStatus == 'partial';
  }

  // ── Order Lines section ───────────────────────────────────────────────────
  Widget _buildOrderLinesSection(Map<String, dynamic> order, List<Map> lines) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _pillTab('Order Lines',
                      selected: _selectedTab == 'Order Lines',
                      onTap: () => setState(() => _selectedTab = 'Order Lines')),
                  const SizedBox(width: 6),
                  _pillTab('Quote Builder',
                      selected: _selectedTab == 'Quote Builder',
                      onTap: () => setState(() => _selectedTab = 'Quote Builder')),
                  const SizedBox(width: 6),
                  _pillTab('Other Info',
                      selected: _selectedTab == 'Other Info',
                      onTap: () => setState(() => _selectedTab = 'Other Info')),
                  const SizedBox(width: 6),
                  _pillTab('Customer Signature',
                      selected: _selectedTab == 'Customer Signature',
                      onTap: () =>
                          setState(() => _selectedTab = 'Customer Signature')),
                ],
              ),
            ),
          ),
          _buildTabContent(order, lines),
        ],
      ),
    );
  }



  Widget _buildTabContent(Map<String, dynamic> order, List<Map> lines) {
    switch (_selectedTab) {
      case 'Quote Builder':
        return _buildQuoteBuilderTab();
      case 'Other Info':
        return _buildOtherInfoTab();
      case 'Customer Signature':
        return _buildCustomerSignatureTab();
      default:
        return _buildOrderLinesTable(order, lines);
    }
  }

  Widget _buildOrderLinesTable(Map<String, dynamic> order, List<Map> lines) {
    const double colProduct  = 343;
    const double colQty      = 137;
    const double colDelivered= 137;
    const double colInvoiced = 137;
    const double colUom      = 137;
    const double colPrice    = 137;
    const double colTax      = 137;
    const double colAmount   = 137;
    const double colAction   = 65;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg   = isDark ? AppColors.darkSurface3 : const Color(0xFFEDEDED);
    final headerText = isDark ? AppColors.darkTextPrimary : const Color(0xFF2B2A2A);
    final cellBg     = isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8);
    final cellText   = isDark ? AppColors.darkTextSecondary : const Color(0xFF484848);
    final divColor   = isDark ? AppColors.darkBorder : const Color(0xFFD8D8D8);

    Widget headerCell(String text, double width) => Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      color: headerBg,
      child: Text(
        text,
        style: AppTextStyles.h3.copyWith(color: headerText, fontSize: 14),
      ),
    );

    Widget dataCell(String text, double width,
        {Color? textColor, bool isProduct = false}) =>
        Container(
          width: width,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          color: cellBg,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isProduct ? AppColors.primary : (textColor ?? cellText),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

    return Container(
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: divColor,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                headerCell('Product', colProduct),
                Container(width: 1, height: 56, color: divColor),
                headerCell('Quantity', colQty),
                Container(width: 1, height: 56, color: divColor),
                headerCell('Delivered', colDelivered),
                Container(width: 1, height: 56, color: divColor),
                headerCell('Invoiced', colInvoiced),
                Container(width: 1, height: 56, color: divColor),
                headerCell('UoM', colUom),
                Container(width: 1, height: 56, color: divColor),
                headerCell('Unit Price', colPrice),
                Container(width: 1, height: 56, color: divColor),
                headerCell('Taxes', colTax),
                Container(width: 1, height: 56, color: divColor),
                headerCell('Amount', colAmount),
                Container(width: 1, height: 56, color: divColor),
              ],
            ),
            // Data rows
            if (lines.isEmpty)
              Container(
                width: colProduct + colQty + colDelivered + colInvoiced +
                    colUom + colPrice + colTax + colAmount + colAction + 8,
                height: 56,
                color: const Color(0xFFF8F8F8),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('No products added.',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextDisabled : AppColors.textDisabled)),
              )
            else
              ...lines.map((line) {
                final m = Map<String, dynamic>.from(line);
                final taxes = m['tax_id'] as List?;
                final taxLabel = taxes != null && taxes.isNotEmpty
                    ? taxes
                    .map((t) =>
                t is List && t.length >= 2 ? t[1] : '')
                    .join(', ')
                    : '-';
                return Column(
                  children: [
                    Container(height: 1, color: divColor),
                    Row(
                      children: [
                        dataCell(_m2oLabel(m['product_id']),
                            colProduct, isProduct: true),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(_fmtQty(m['product_uom_qty']), colQty),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(_fmtQty(m['qty_delivered']), colDelivered),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(_fmtQty(m['qty_invoiced']), colInvoiced),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(_m2oLabel(m['product_uom']), colUom),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(_fmtMoney(order, m['price_unit']), colPrice),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(taxLabel, colTax),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
                        dataCell(_fmtMoney(order, m['price_subtotal']), colAmount),
                        Container(width: 1, height: 56, color: const Color(0xFFD8D8D8)),
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


  // ── Totals ────────────────────────────────────────────────────────────────
  Widget _buildTotalsSection(Map<String, dynamic> order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terms box
          Container(
            width: double.infinity,
            height: 102,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: AppColors.darkBorder) : null,
            ),
            alignment: Alignment.topLeft,
            child: Text(
              'Terms and Conditions',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextHint : AppColors.textHint,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Untaxed Amount
          Row(
            children: [
              Text(
                'Untaxed Amount:',
                style: AppTextStyles.h2.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              Text(
                _fmtMoney(order, order['amount_untaxed']),
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Total
          Row(
            children: [
              Text(
                'Total',
                style: AppTextStyles.h2.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              Text(
                _fmtMoney(order, order['amount_total']),
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildQuoteBuilderTab() {
    final order = _saleOrder!;
    final header = order['note']?.toString() ?? '';
    final template = _quotationTemplateLabel(order);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Template'),
          const SizedBox(height: 6),
          _infoBox(template),
          const SizedBox(height: 16),
          _sectionLabel('Header / Notes'),
          const SizedBox(height: 6),
          _infoBox(header.isEmpty ? '-' : header),
          const SizedBox(height: 16),
          _sectionLabel('Footer'),
          const SizedBox(height: 6),
          _infoBox('-'),
        ],
      ),
    );
  }

  Widget _buildOtherInfoTab() {
    final order = _saleOrder!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SALES
          _sectionHeader('SALES'),
          _infoRow('Salesperson',     _m2oLabel(order['user_id'])),
          _infoRow('Sales Team',      _m2oLabel(order['team_id'])),
          _infoRow('Company',         _m2oLabel(order['company_id'])),
          _infoRow('Online signature',
              order['require_signature'] == true ? '✓' : ''),
          _infoRow('Online payment',
              order['require_payment'] == true
                  ? '✓ of ${order['prepayment_percent'] ?? 100}%'
                  : ''),
          _infoRow('Customer Reference',
              order['client_order_ref']?.toString() ?? ''),
          const SizedBox(height: 20),

          // INVOICING
          _sectionHeader('INVOICING'),
          _infoRow('Fiscal Position', _m2oLabel(order['fiscal_position_id'])),
          _infoRow('Project',         _m2oLabel(order['project_id'])),
          _infoRow('Invoicing Journal',_m2oLabel(order['journal_id'])),
          _infoRow('Invoice Status',  _invoiceStatusLabel(order['invoice_status'])),
          const SizedBox(height: 20),

          // DELIVERY
          _sectionHeader('DELIVERY'),
          _infoRow('Warehouse',         _m2oLabel(order['warehouse_id'])),
          _infoRow('Incoterm',          _m2oLabel(order['incoterm'])),
          _infoRow('Incoterm Location', _m2oLabel(order['incoterm_location'])),
          _infoRow('Shipping Policy',   _pickingPolicyLabel(order['picking_policy'])),
          _infoRow('Delivery Date',
              order['commitment_date'] != null && order['commitment_date'] != false
                  ? _formatDate(order['commitment_date'])
                  : order['effective_date'] != null && order['effective_date'] != false
                  ? 'Expected: ${_formatDate(order['effective_date'])}'
                  : ''),
          _infoRow('Delivery Status',   _deliveryStatusLabel(order['delivery_status'])),
          const SizedBox(height: 20),

          // TRACKING
          _sectionHeader('TRACKING'),
          _infoRow('Source Document', order['origin']?.toString() ?? ''),
          _infoRow('Campaign',        _m2oLabel(order['campaign_id'])),
          _infoRow('Medium',          _m2oLabel(order['medium_id'])),
          _infoRow('Source',          _m2oLabel(order['source_id'])),
        ],
      ),
    );
  }

  String _invoiceStatusLabel(dynamic v) {
    switch (v?.toString()) {
      case 'upselling':  return 'Upselling Opportunity';
      case 'invoiced':   return 'Fully Invoiced';
      case 'to invoice': return 'To Invoice';
      case 'no':         return 'Nothing to Invoice';
      default:           return v?.toString() ?? '-';
    }
  }

  String _pickingPolicyLabel(dynamic v) {
    switch (v?.toString()) {
      case 'direct': return 'As soon as possible';
      case 'one':    return 'When all products are ready';
      default:       return v?.toString() ?? '-';
    }
  }

  String _deliveryStatusLabel(dynamic v) {
    switch (v?.toString()) {
      case 'pending':    return 'Not Delivered';
      case 'partial':    return 'Partially Delivered';
      case 'full':       return 'Fully Delivered';
      default:           return v?.toString() ?? '-';
    }
  }

  Widget _buildCustomerSignatureTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = _saleOrder!;
    final signedBy  = order['signed_by']?.toString()  ?? '';
    final signedOn  = order['signed_on']  != null && order['signed_on'] != false
        ? _formatDate(order['signed_on']) : '';
    final sigRaw    = order['signature'];
    final hasSignature = sigRaw != null && sigRaw != false &&
        sigRaw.toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Signed By', signedBy.isEmpty ? '-' : signedBy),
          const SizedBox(height: 12),
          _infoRow('Signed On', signedOn.isEmpty ? '-' : signedOn),
          const SizedBox(height: 16),
          _sectionLabel('Signature'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasSignature
                ? Image.memory(
              _decodeBase64Sig(sigRaw.toString()),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
              const Center(child: Text('Could not load signature')),
            )
                : Center(
              child: Text('No signature',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextDisabled : AppColors.textDisabled)),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List _decodeBase64Sig(String raw) {
    // Odoo returns base64 with or without data URI prefix
    final clean = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(clean);
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Text(title,
                style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    letterSpacing: 0.5));
          }),
          const Divider(height: 12),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(title,
        style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary));
  }

  Widget _infoBox(String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE8E8E8)),
      ),
      child: Text(value,
          style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textPrimary)),
    );
  }


  Widget _buildChatterSection() {
    final saleOrderId = _saleOrder?['id'] as int?;
    if (saleOrderId == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 520,
        child: ChatterWidget(
          model: 'sale.order',
          recordId: saleOrderId,
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _pillTab(String label,
      {bool selected = false, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<void> _onCreateInvoiceTapped() async {
    final saleOrderId = _saleOrder?['id'] as int?;
    if (saleOrderId == null) return;

    final result = await _showCreateInvoiceDialog(saleOrderId);
    if (result != null && mounted) {
      final isQueued = result['queued_offline'] == true;
      if (isQueued) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invoice creation queued — will sync when back online.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ));
      } else {
        // Navigate to invoice and wait for result
        await Get.to(() => const InvoiceView(),
            arguments: <String, dynamic>{'invoice': result});

        // When user comes back, check if invoice was confirmed
        if (mounted) {
          final freshOrder = await _repository.fetchSaleOrderById(saleOrderId);
          if (mounted && freshOrder != null) {
            setState(() {
              _saleOrder = freshOrder;
              // Hide button if invoice status is invoiced or fully invoiced
              final invoiceStatus = freshOrder['invoice_status']?.toString() ?? '';
              _invoiceConfirmed = invoiceStatus == 'invoiced';
            });
          }
        }
      }
    }
  }

  Future<void> _openInvoicesList() async {
    final saleOrderId = _saleOrder?['id'];
    final id = saleOrderId is int ? saleOrderId : int.tryParse('$saleOrderId');
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale order not found.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Get.to(
          () => const InvoiceView(),
      arguments: <String, dynamic>{'saleOrderId': id},
    );
  }

  Future<Map<String, dynamic>?> _showCreateInvoiceDialog(int saleOrderId) async {
    String selectedMethod = 'delivered';
    double? amount;
    final amountCtrl = TextEditingController();
    bool isCreating = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
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
                        'Create Invoice',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(null),
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

                  // ── Invoice Method label ──
                  Text(
                    'Invoice Method',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Method tiles ──
                  _invoiceMethodTile(
                    label: 'Regular Invoice',
                    subtitle: 'Invoice based on delivered quantities',
                    value: 'delivered',
                    groupValue: selectedMethod,
                    onChanged: (v) => setS(() => selectedMethod = v!),
                  ),
                  _invoiceMethodTile(
                    label: 'Down Payment (Percentage)',
                    subtitle: 'Invoice a percentage of the total amount',
                    value: 'percentage',
                    groupValue: selectedMethod,
                    onChanged: (v) => setS(() => selectedMethod = v!),
                  ),
                  _invoiceMethodTile(
                    label: 'Down Payment (Fixed)',
                    subtitle: 'Invoice a fixed amount',
                    value: 'fixed',
                    groupValue: selectedMethod,
                    onChanged: (v) => setS(() => selectedMethod = v!),
                  ),

                  // ── Amount field ──
                  if (selectedMethod != 'delivered') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: selectedMethod == 'percentage'
                            ? 'Percentage (%)'
                            : 'Fixed Amount',
                        filled: true,
                        fillColor: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      onChanged: (v) => amount = double.tryParse(v),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Create button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isCreating
                          ? null
                          : () async {
                        setS(() => isCreating = true);
                        final repo = Get.find<OrderRepository>();
                        final invoice = await repo.createInvoiceFromSaleOrder(
                          saleOrderId: saleOrderId,
                          method: selectedMethod,
                          amount: selectedMethod != 'delivered' ? amount : null,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(invoice);
                      },
                      child: isCreating
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Create',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _invoiceMethodTile({
    required String label,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary : AppColors.textSecondary)),
    );
  }

  void _openDeliveries() {
    final saleOrderId = _saleOrder?['id'] as int?;
    if (saleOrderId == null) return;
    Get.to(() => const DeliveryListView(),
        arguments: <String, dynamic>{'saleOrderId': saleOrderId})
        ?.then((_) async {
      // Refresh sale order data when coming back from delivery
      if (_saleOrder?['id'] != null) {
        final fresh = await _repository.fetchSaleOrderById(_saleOrder!['id'] as int);
        if (mounted && fresh != null) {
          setState(() => _saleOrder = fresh);
        }
      }
    });
  }
}