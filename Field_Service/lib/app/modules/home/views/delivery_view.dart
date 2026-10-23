import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/order_repository.dart';

class DeliveryListView extends StatefulWidget {
  const DeliveryListView({super.key});

  @override
  State<DeliveryListView> createState() => _DeliveryListViewState();
}

class _DeliveryListViewState extends State<DeliveryListView> {
  final OrderRepository _repo = Get.find<OrderRepository>();
  late final int _saleOrderId;

  List<Map<String, dynamic>> _pickings = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _saleOrderId = (args?['saleOrderId'] as int?) ?? 0;
    _fetchPickings();
  }

  Future<void> _fetchPickings() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final list = await _repo.fetchPickingsForSaleOrder(_saleOrderId);
      if (!mounted) return;
      setState(() { _pickings = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _stateLabel(String? state) {
    switch (state) {
      case 'draft':     return 'Draft';
      case 'waiting':   return 'Waiting';
      case 'confirmed': return 'Ready';
      case 'assigned':  return 'Ready';
      case 'done':      return 'Done';
      case 'cancel':    return 'Cancelled';
      default:          return state ?? '-';
    }
  }

  Color _stateColor(String? state) {
    switch (state) {
      case 'done':      return Colors.green;
      case 'cancel':    return Colors.grey;
      case 'assigned':
      case 'confirmed': return Colors.blue;
      default:          return Colors.orange;
    }
  }

  String _m2oLabel(dynamic v) {
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return '-';
  }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final dt = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (dt == null) return raw.toString();
    return DateFormat('MM/dd/yyyy HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF4F4F4),
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
            // Header
            Container(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text(AppStrings.deliveriesSubtitle,
                      style: AppTextStyles.h2.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _fetchPickings,
                    child: const Icon(Icons.refresh_rounded,
                        color: AppColors.primary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary))
                  : _error.isNotEmpty
                  ? Center(child: Text(_error))
                  : _pickings.isEmpty
                  ? const Center(
                  child: Text(AppStrings.noDeliveries))
                  : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _fetchPickings,
                child: ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _pickings.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = _pickings[i];
                    final state = p['state']?.toString();
                    return GestureDetector(
                      onTap: () => Get.to(
                            () => DeliveryDetailView(
                            picking: p),
                        arguments: <String, dynamic>{
                          'picking': p,
                          'saleOrderId': _saleOrderId,
                        },
                      )?.then((_) => _fetchPickings()),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: isDark ? Border.all(color: AppColors.darkBorder) : null,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left colored bar
                            Container(
                              width: 4,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['name']?.toString() ?? '-',
                                          style: AppTextStyles.h3.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _stateColor(state).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: _stateColor(state), width: 1.2),
                                        ),
                                        child: Text(
                                          _stateLabel(state),
                                          style: TextStyle(
                                            color: _stateColor(state),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${_m2oLabel(p['location_id'])}  →  ${_m2oLabel(p['location_dest_id'])}',
                                          style: AppTextStyles.bodySmall.copyWith(
                                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF555555)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined,
                                          size: 13, color: isDark ? AppColors.darkTextHint : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Scheduled: ${_formatDate(p['scheduled_date'])}',
                                        style: AppTextStyles.caption.copyWith(
                                            color: isDark ? AppColors.darkTextHint : const Color(0xFF888888)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.receipt_outlined,
                                          size: 13, color: isDark ? AppColors.darkTextHint : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Source: ${p['origin']?.toString() ?? '-'}',
                                        style: AppTextStyles.caption.copyWith(
                                            color: isDark ? AppColors.darkTextHint : const Color(0xFF888888)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (state != 'done' && state != 'cancel')
                              Padding(
                                padding: const EdgeInsets.only(top: 28),
                                child: Icon(Icons.chevron_right_rounded,
                                    color: isDark ? AppColors.darkTextSecondary : Colors.grey, size: 22),
                              ),
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


}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery Detail + Validate
// ─────────────────────────────────────────────────────────────────────────────
class DeliveryDetailView extends StatefulWidget {
  final Map<String, dynamic> picking;

  const DeliveryDetailView({super.key, required this.picking});

  @override
  State<DeliveryDetailView> createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  final OrderRepository _repo = Get.find<OrderRepository>();
  List<Map<String, dynamic>> _moveLines = [];
  bool _isLoading = true;
  bool _isValidating = false;
  String _selectedTab = 'Operations';

  @override
  void initState() {
    super.initState();
    _fetchLines();
  }

  Future<void> _fetchLines() async {
    setState(() => _isLoading = true);
    final id = widget.picking['id'] as int? ?? 0;
    final lines = await _repo.fetchPickingMoveLines(id);
    if (!mounted) return;
    setState(() { _moveLines = lines; _isLoading = false; });
  }

  String _m2oLabel(dynamic v) {
    if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
    return '-';
  }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == false) return '-';
    final dt = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (dt == null) return raw.toString();
    return DateFormat('MM/dd/yyyy HH:mm').format(dt.toLocal());
  }

  Future<void> _onValidate() async {
    final id = widget.picking['id'] as int? ?? 0;
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
                      AppStrings.validateDelivery,
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700,
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
                  AppStrings.validateDeliveryMessage,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // ── Validate button ──
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
                      AppStrings.validate,
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

    setState(() => _isValidating = true);
    final ok = await _repo.validatePicking(id);
    if (!mounted) return;
    setState(() => _isValidating = false);

    final isOffline = !Get.find<ConnectivityService>().hasConnection;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (isOffline ? AppStrings.deliverySuccess : AppStrings.deliverySuccessMessage)
          : AppStrings.failedDelivery),
      backgroundColor: ok
          ? (isOffline ? AppColors.stageInProgress : AppColors.success)
          : AppColors.error,
    ));
    if (ok && !isOffline) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.picking;
    final state = p['state']?.toString() ?? '';
    final isDone = state == 'done' || state == 'cancel';

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
            // ── Header ──────────────────────────────────
            Container(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: back + title + icons
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p['name']?.toString() ?? 'Delivery',
                          style: AppTextStyles.h2.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (!isDone) ...[
                            _actionButton(
                              text: _isValidating ? '' : 'Validate',
                              isPrimary: true,
                              onPressed: _isValidating ? null : _onValidate,
                              isLoading: _isValidating,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _actionButton(
                            text: AppStrings.cancelDelivery,
                            isPrimary: false,
                            onPressed: () => Get.back(),
                          ),
                        ],
                      ),
                      // Right icon

                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Form Fields ──────────────────
                    Container(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formRow('Delivery Address', _m2oLabel(p['partner_id'])),
                          _formRow('Operation Type', _m2oLabel(p['picking_type_id'])),
                          _formRow('Source Location', _m2oLabel(p['location_id'])),
                          _formRow('Scheduled Date', _formatDate(p['scheduled_date'])),
                          _formRow('Deadline', _formatDate(p['date_deadline'] ?? p['scheduled_date'])),
                          _formRow('Source Document', p['origin']?.toString() ?? '-'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Tab Bar ──────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 30,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ['Operations', 'Additional Info', 'Note'].length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final label = ['Operations', 'Additional Info', 'Note'][i];
                            final active = _selectedTab == label;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedTab = label),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  label,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: active
                                        ? AppColors.white
                                        : (isDark ? AppColors.darkTextSecondary : const Color(0xFF999999)),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Tab Content ──────────────────
                    _buildTabContent(p),
                  ],
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
            width: 14, height: 14,
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

  Widget _buildTabContent(Map<String, dynamic> p) {
    switch (_selectedTab) {
      case 'Additional Info': return _buildAdditionalInfoTab(p);
      case 'Note':            return _buildNoteTab(p);
      default:                return _buildOperationsTab();
    }
  }

  Widget _buildOperationsTab() {
    const double colProduct = 491;
    const double colDemand  = 137;
    const double colQty     = 137;
    const double colUnit    = 137;

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
      child: Text(text,
          style: AppTextStyles.h3.copyWith(color: headerText, fontSize: 14)),
    );

    Widget dataCell(String text, double width, {bool isProduct = false}) => Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      color: cellBg,
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isProduct ? AppColors.primary : cellText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    Widget divider() => Container(width: 1, color: divColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: divColor,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  headerCell('Product', colProduct),
                  divider(),
                  headerCell('Demand', colDemand),
                  divider(),
                  headerCell('Quantity', colQty),
                  divider(),
                  headerCell('Unit', colUnit),
                ],
              ),
              // Data rows
              if (_moveLines.isEmpty)
                Container(
                  width: colProduct + colDemand + colQty + colUnit + 3,
                  height: 56,
                  color: const Color(0xFFF8F8F8),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(AppStrings.noProductsFound,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextDisabled : AppColors.textDisabled)),
                )
              else
                ...(_moveLines.map((m) {
                  final qty  = (m['product_uom_qty'] as num?)?.toStringAsFixed(2) ?? '0';
                  final done = (m['quantity'] as num?)?.toStringAsFixed(2) ?? '0';
                  return Column(
                    children: [
                      Container(height: 1, color: divColor),
                      Row(
                        children: [
                          dataCell(_m2oLabel(m['product_id']), colProduct, isProduct: true),
                          divider(),
                          dataCell(qty, colDemand),
                          divider(),
                          dataCell(done, colQty),
                          divider(),
                          dataCell(_m2oLabel(m['product_uom']), colUnit),
                        ],
                      ),
                    ],
                  );
                })),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoTab(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('OTHER INFORMATION'),
          _formRow('Shipping Policy', _shippingPolicy(p['move_type'])),
          _formRow('Responsible', _m2oLabel(p['user_id'])),
          _formRow('Procurement Group', _m2oLabel(p['group_id'])),
          _formRow('Sales Order', p['origin']?.toString() ?? '-'),
          _formRow('Company', _m2oLabel(p['company_id'])),
          _formRow('Project', _m2oLabel(p['project_id'])),
          const SizedBox(height: 8),
          _sectionHeader('FIELD SERVICE INFORMATION'),
          _formRow('Field Service Order', _m2oLabel(p['fsm_order_id'])),
        ],
      ),
    );
  }

  Widget _buildNoteTab(Map<String, dynamic> p) {
    final note = p['note']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFEEEEEE)),
        ),
        child: Text(
          note.isEmpty ? AppStrings.addInternalNote : note,
          style: AppTextStyles.bodyMedium.copyWith(
            color: note.isEmpty
                ? (isDark ? AppColors.darkTextDisabled : const Color(0xFFAAAAAA))
                : (isDark ? AppColors.darkTextPrimary : const Color(0xFF333333)),
          ),
        ),
      ),
    );
  }

  String _shippingPolicy(dynamic v) {
    switch (v?.toString()) {
      case 'direct': return 'As soon as possible';
      case 'one':    return 'When all products are ready';
      default:       return v?.toString() ?? '-';
    }
  }

  Widget _sectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                letterSpacing: 0.6,
              )),
          const SizedBox(height: 6),
          Divider(height: 1, color: isDark ? AppColors.darkDivider : const Color(0xFFDDDDDD)),
        ],
      ),
    );
  }

  Widget _formRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.h3.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              )),
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
}