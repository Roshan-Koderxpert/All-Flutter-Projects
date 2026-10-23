  import 'dart:async';

  import 'package:flutter/material.dart';
  import 'package:flutter_map/flutter_map.dart';
  import 'package:intl/intl.dart';
  import 'package:flutter/services.dart';
  import 'package:get/get.dart';
  import 'package:latlong2/latlong.dart';

  import '../../../core/constants/app_colors.dart';
  import '../../../core/constants/app_strings.dart';
  import '../../../core/constants/assets.dart';
  import '../../../core/theme/text_styles.dart';
  import '../../../core/constants/odoo_orders_config.dart';
  import '../../../core/utils/logger.dart';
  import '../../../core/widgets/chatter.dart';
  import '../../../data/repositories/order_repository.dart';
  import '../../../routes/app_routes.dart';
  import '../controllers/order_controller.dart';
  import 'invoice_view.dart';

  class OrderCreateView extends StatefulWidget {
    const OrderCreateView({super.key});

    @override
    State<OrderCreateView> createState() => _OrderCreateViewState();
  }

  class _OrderCreateViewState extends State<OrderCreateView> {
    final _formKey = GlobalKey<FormState>();
    final OrderRepository _repository = Get.find<OrderRepository>();

    final _textControllers = <String, TextEditingController>{};
    /// True until [_initFormData] finishes (options +, for existing orders, hydration).
    bool _isBootstrapping = true;
    bool _isLoadingOptions = true;
    bool _isSaving = false;
    String _loadError = '';
    final Map<int, int?> _timesheetRowTypeIds = {};
    final Map<int, int?> _timesheetRowEmpIds = {};
    // Worksheet state
    bool _worksheetModuleInstalled = false;
    bool _hasWorksheetTemplate = false;


    List<_SelectFieldConfig> get _primaryFields => [
      _SelectFieldConfig(key: 'partner_id',           label: AppStrings.orderFieldPartner),
      _SelectFieldConfig(key: 'template_id',          label: AppStrings.orderFieldTemplate),
      _SelectFieldConfig(key: 'type',                 label: AppStrings.orderFieldType),
      _SelectFieldConfig(key: 'location_id',          label: AppStrings.orderFieldLocation),
      _SelectFieldConfig(key: 'person_id',            label: AppStrings.orderFieldAssignedTo),
      _SelectFieldConfig(key: 'vehicle_id',           label: AppStrings.orderFieldVehicle),
      _SelectFieldConfig(key: 'company_id',           label: AppStrings.orderFieldCompany),
      _SelectFieldConfig(key: 'worksheet_template_id',label: AppStrings.orderFieldWorksheetTemplate),
    ];

    List<_SelectFieldConfig> get _scheduleFields => [
      _SelectFieldConfig(key: 'request_early',        label: AppStrings.orderFieldEarliestRequestDate),
      _SelectFieldConfig(key: 'request_late',         label: AppStrings.orderFieldLatestRequestDate),
      _SelectFieldConfig(key: 'scheduled_date_start', label: AppStrings.orderFieldScheduledStart),
      _SelectFieldConfig(key: 'scheduled_duration',   label: AppStrings.orderFieldScheduledDuration),
      _SelectFieldConfig(key: 'scheduled_date_end',   label: AppStrings.orderFieldScheduledEnd),
    ];


    final Map<String, List<String>> _optionsByField = {
      'partner_id': [],
      'template_id': [],
      'type': [],
      'location_id': [],
      'person_id': [],
      'vehicle_id': [],
      'company_id': [],
      'worksheet_template_id': [],
      'request_early': <String>[],
      'request_late': <String>[],
      'scheduled_date_start': <String>[],
      'scheduled_duration': <String>[],
      'scheduled_date_end': <String>[],
      'timesheet_type_id': [],
      'employee_id': [],
      'duration': ['0.00'],
    };

    final Map<String, String?> _selectedByField = {};
    final Map<String, dynamic> _selectedFieldIdByKey = {};
    final Map<String, List<dynamic>> _primaryOptionIds = {};
    List<dynamic> _timesheetTypeIds = [];
    List<dynamic> _employeeIds = [];
    int? _defaultTimesheetTypeOdooId;
    int? _defaultEmployeeOdooId;
    bool _isMapLoading = false;
    String _mapError = '';
    double? _mapLatitude;
    double? _mapLongitude;

    final List<String> _processTabs =  [
      AppStrings.orderTabPlanning,
      AppStrings.orderTabInstructions,
      AppStrings.orderTabExecution,
      AppStrings.orderTabMap,
      AppStrings.orderTabTimesheet,
    ];
    String _selectedProcessTab = AppStrings.orderTabPlanning;


    int _priority = 0;

    final List<_WorkerRow> _workers = [];
    final List<_TimesheetRow> _timesheetRows = [];
    int? _existingOrderId;
    bool get _isExistingOrder => _existingOrderId != null;
    bool _isClosed = false;
    int? _currentStageId;
    String _currentStageName = '';
    List<Map<String, dynamic>> _availableStages = const <Map<String, dynamic>>[];
    bool _isTimerRunning = false;
    Duration _elapsed = Duration.zero;
    Timer? _timer;
    bool _isLogDialogOpen = false;

    // Vehicle stock wizard state
    Map<String, dynamic> _vehicleStockWizardDefaults = {};
    List<Map<String, dynamic>> _vehicleStockProducts = [];
    bool _isLoadingVehicleStock = false;
    bool _hasLinkedSaleOrder = false;
    bool _hasCustomerInvoice = false;

    @override
    void initState() {
      super.initState();
      final args = Get.arguments;
      if (args is Map && args['orderId'] is int) {
        _existingOrderId = args['orderId'] as int;
      }
      for (final f in [..._primaryFields, ..._scheduleFields]) {
        _selectedByField[f.key] = null;
      }
      _textControllers['description'] = TextEditingController();
      _textControllers['resolution'] = TextEditingController();
      _textControllers['todo'] = TextEditingController();
      _textControllers['location_directions'] = TextEditingController();
      _textControllers['date_start'] = TextEditingController();
      _textControllers['date_end'] = TextEditingController();
      _textControllers['duration'] = TextEditingController(text: '0.00');
      _textControllers['scheduled_duration'] = TextEditingController();
      _initFormData();
    }

    @override
    void dispose() {
      _timer?.cancel();
      for (final c in _textControllers.values) {
        c.dispose();
      }
      super.dispose();
    }

    @override
    void reassemble() {
      super.reassemble();
      if (_timesheetRows.isEmpty) return;
      final backup = _timesheetRows.map((r) => r.toOdooCacheLite()).toList();
      setState(() {
        _timesheetRows
          ..clear()
          ..addAll(
            backup.map(
              (e) => _TimesheetRow.fromOdooMap(Map<String, dynamic>.from(e)),
            ),
          );
      });
    }

    @override
    Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
          toolbarHeight: 20,
          backgroundColor: AppColors.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: AppColors.primary,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: SafeArea(
          child: _isBootstrapping
              ? _buildBootstrapPlaceholder(isDark)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCreateHeader(),
                            const SizedBox(height: 4),
                            _buildTopFilters(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._primaryFields.map(_buildSelectField),
                              const SizedBox(height: 5),
                              _buildPriority(),
                              const SizedBox(height: 5),
                              _buildTextArea(
                                title: AppStrings.orderDescriptionTitle,
                                hint: AppStrings.orderDescriptionHint,
                                controller: _textControllers['description']!,
                              ),
                              const SizedBox(height: 12),
                              _buildTextArea(
                                title: AppStrings.orderResolutionTitle,
                                hint: AppStrings.orderResolutionHint,
                                controller: _textControllers['resolution']!,
                              ),
                              const SizedBox(height: 18),
                              _buildProcessTabs(),
                              const SizedBox(height: 18),
                              ..._buildSelectedProcessTabSection(),
                              const SizedBox(height: 18),
                              _buildChatterTabs(),
                              const SizedBox(height: 14),
                              _buildActivity(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }


    Widget _buildCreateHeader() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bool hasStartedTimer = _elapsed > Duration.zero || _isTimerRunning;

      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 5, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            GestureDetector(
              onTap: () => Get.back(),
              child: Image.asset(
                AppImage.back,
                width: 25,
                height: 25,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),

            const SizedBox(width: 8),

            // Title
            Text(
              AppStrings.navOrder,
              style: AppTextStyles.h1.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),

            const Spacer(),

            // Timer controls (only for existing orders)
            if (_isExistingOrder) ...[
              if (!hasStartedTimer) ...[
                // Green play button
                GestureDetector(
                  onTap: _onTimerStartPressed,
                  child: Container(
                    width: 33,
                    height: 33,
                    decoration: const BoxDecoration(
                      color: Color(0xFF06C270),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ] else ...[
                // Timer text
                Text(
                  _formatElapsed(_elapsed),
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                // Yellow pause/resume button
                GestureDetector(
                  onTap: _onTimerPauseResumePressed,
                  child: Container(
                    width: 33,
                    height: 33,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Red stop button
                GestureDetector(
                  onTap: _onTimerStopPressed,
                  child: Container(
                    width: 33,
                    height: 33,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    }

    Widget _buildTopFilters() {

      final leftActions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(
            text: _isSaving ? AppStrings.orderSaving : AppStrings.orderSave,
            isPrimary: true,
            onPressed: _isSaving ? null : _onSavePressed,
          ),
          const SizedBox(width: 8),
          _actionButton(
            text: AppStrings.orderCancel,
            isPrimary: false,
            onPressed: _onCancelPressed,
          ),
        ],
      );

      final rightActions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStageMenuButton(),
          if (_isExistingOrder) ...[
            const SizedBox(width: 8),
            _buildFlashStockAction(),
          ],
          const SizedBox(width: 8),
          _buildMoreActionsButton(),
        ],
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: leftActions,
                  ),
                ),
              ),
              rightActions,
            ],
          ),

        ],
      );
    }

    Widget _actionButton({
      required String text,
      required bool isPrimary,
      required VoidCallback? onPressed,
    }) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SizedBox(
        height: 34,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: isPrimary ? AppColors.primary : (isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1)),
            side: BorderSide(color: isPrimary ? AppColors.primary : (isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB))),
            foregroundColor: isPrimary ? AppColors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            text,
            style: AppTextStyles.h3.copyWith(
              color: isPrimary ? AppColors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget _iconCard(String iconPath) {
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
            color: isDark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      );
    }

    int? _flashSelectedPartnerId() => _m2oIntId(_selectedFieldIdByKey['partner_id']);

    bool _flashVehicleSelectedOnForm() =>
        _m2oIntId(_selectedFieldIdByKey['vehicle_id']) != null;

    bool _showFlashProductsItem() => _flashSelectedPartnerId() != null;

    bool _showFlashStockItem() =>
        _isExistingOrder &&
        _existingOrderId != null &&
        _flashVehicleSelectedOnForm();

    bool _showFlashSaleOrderItem() => _isExistingOrder && _hasLinkedSaleOrder;

    bool _showFlashInvoiceItem() => _isExistingOrder && _hasCustomerInvoice;

    bool _showFlashWorksheetItem() => _isExistingOrder && _hasWorksheetTemplate;

    bool _showFlashMenuButton() =>
        _showFlashProductsItem() ||
        _showFlashStockItem() ||
        _showFlashSaleOrderItem() ||
        _showFlashInvoiceItem() ||
        _showFlashWorksheetItem();

    Widget _buildFlashStockAction() {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (!_showFlashMenuButton()) return const SizedBox.shrink();

      return PopupMenuButton<String>(
        tooltip: AppStrings.orderStockActions,
        onSelected: (value) {
          if (value == 'stock') {
            _openStockScreen();
          } else if (value == 'products') {
            _onProductsButtonPressed();
          } else if (value == 'saleorder') {
            _openSaleOrderScreen();
          } else if (value == 'invoices') {
            _openInvoiceFromOrder();
          } else if (value == 'worksheet') {
            _openWorksheetList();
          }
        },
        itemBuilder: (_) => [
          if (_showFlashStockItem())
             PopupMenuItem<String>(
              value: 'stock',
              child: Text(AppStrings.orderStockActionStock),
            ),
          if (_showFlashProductsItem())
             PopupMenuItem<String>(
              value: 'products',
              child: Text(AppStrings.orderStockActionProducts),
            ),
          if (_showFlashSaleOrderItem())
             PopupMenuItem<String>(
              value: 'saleorder',
              child: Text(AppStrings.orderStockActionSaleOrder),
            ),
          if (_showFlashInvoiceItem())
             PopupMenuItem<String>(
              value: 'invoices',
              child: Text(AppStrings.orderStockActionInvoices),
            ),
          if (_showFlashWorksheetItem())
             PopupMenuItem<String>(
              value: 'worksheet',
              child: Text(AppStrings.orderWorksheetButton),
            ),
        ],
        child: Container(
          width: 33,
          height: 33,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.flash_on_rounded,
            size: 20,
            color: isDark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      );
    }

    Widget _buildStageMenuButton() {
      if (!_isExistingOrder) return _iconCard(AppImage.setting);
      final stages = _availableStages;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (stages.isEmpty) return _iconCard(AppImage.setting);
      return PopupMenuButton<int>(
        color: isDark ? AppColors.darkSurface2 : AppColors.white,
        tooltip: _currentStageName.isEmpty
            ? 'Current stage'
            : 'Current stage: $_currentStageName',
        onSelected: _onStageSelected,
        itemBuilder: (_) {
          final items = <PopupMenuEntry<int>>[];
          items.addAll(
            stages.map((stage) {
              final stageId = stage['id'] as int;
              final stageName = stage['name']?.toString() ?? '—';
              final selected = stageId == _currentStageId;
              return PopupMenuItem<int>(
                value: stageId,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFDE6E6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(stageName,style: TextStyle(color: selected ? AppColors.primary : AppColors.darkPrimary),),
                ),
              );
            }),
          );
          return items;
        },
        child: _iconCard(AppImage.setting),
      );
    }

    Widget _buildMoreActionsButton() {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (!_isExistingOrder || _isClosed) {
        return _iconCard(AppImage.more);
      }
      return PopupMenuButton<String>(
        color: isDark ? AppColors.darkSurface2 : AppColors.white,
        tooltip: 'Order actions',
        onSelected: (value) async {
          if (value == 'complete') {
            await _onOrderActionPressed('complete');
          } else if (value == 'cancel') {
            await _onOrderActionPressed('cancel');
          }
        },
        itemBuilder: (_) =>  [
          PopupMenuItem<String>(
            value: 'complete',
            child: Text(AppStrings.orderActionComplete),
          ),
          PopupMenuItem<String>(
            value: 'cancel',
            child: Text(AppStrings.orderActionCancelOrder),
          ),
        ],
        child: _iconCard(AppImage.more),
      );
    }

    Future<void> _onProductsButtonPressed() async {
      final rawId = _selectedFieldIdByKey['partner_id'];
      int? partnerId;
      if (rawId is int) {
        partnerId = rawId;
      } else if (rawId is num) {
        partnerId = rawId.toInt();
      } else if (rawId != null) {
        partnerId = int.tryParse(rawId.toString());
      }
      if (partnerId == null) return;

      final result = await Get.toNamed(
        AppRoutes.orderProducts,
        arguments: <String, dynamic>{
          'partnerId': partnerId,
          'fsmOrderId': _existingOrderId,
        },
      );

      // If products page returned a sale order (online or offline placeholder),
      // navigate directly to it
      if (result != null && result is Map<String, dynamic> && mounted) {
        Get.toNamed(
          AppRoutes.saleOrder,
          arguments: <String, dynamic>{
            'saleOrderData': result,
            'fsmOrderId': _existingOrderId,
            'partnerId': partnerId,
          },
        );
      }
      if (mounted) unawaited(_refreshSaleOrderAndInvoiceFlags());
    }

    Future<void> _openSaleOrderScreen() async {
      final orderId = _existingOrderId;
      if (orderId == null) return;
      await Get.toNamed(
        AppRoutes.saleOrder,
        arguments: <String, dynamic>{
          'fsmOrderId': orderId,
          'partnerId': _m2oIntId(_selectedFieldIdByKey['partner_id']),
        },
      );
      if (mounted) unawaited(_refreshSaleOrderAndInvoiceFlags());
    }

    Future<void> _openInvoiceFromOrder() async {
      final fsmOrderId = _existingOrderId;
      if (fsmOrderId == null || fsmOrderId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(AppStrings.orderNotFound),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      final saleOrder = await _repository.fetchSaleOrderForFsmOrder(fsmOrderId);
      if (!mounted) return;
      final saleOrderId = saleOrder?['id'];
      final id = saleOrderId is int ? saleOrderId : int.tryParse('$saleOrderId');
      if (id == null || id <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(AppStrings.orderSaleNotFound),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await Get.to(
        () => const InvoiceView(),
        arguments: <String, dynamic>{'saleOrderId': id},
      );
      if (mounted) unawaited(_refreshSaleOrderAndInvoiceFlags());
    }

    // Replace the existing _openWorksheetList method:
    Future<void> _openWorksheetList() async {
      final orderId = _existingOrderId;
      if (orderId == null) return;
      await Get.toNamed(
        AppRoutes.worksheetList,
        arguments: <String, dynamic>{
          'fsmOrderId': orderId,
        },
      );
    }

    Widget _buildSelectField(_SelectFieldConfig field) {
      // Hide worksheet_template_id if module not installed
      if (field.key == 'worksheet_template_id' && !_worksheetModuleInstalled) {
        return const SizedBox.shrink();
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final options = _optionsByField[field.key] ?? const <String>[];
      final ids = _primaryOptionIds[field.key] ?? const <dynamic>[];
      final labelToId = <String, dynamic>{};
      for (var i = 0; i < options.length; i++) {
        final label = options[i];
        if (labelToId.containsKey(label)) continue;
        labelToId[label] = i < ids.length ? ids[i] : null;
      }
      final uniqueOptions = labelToId.keys.toList();
      final selectedValue = _selectedByField[field.key];
      final safeSelectedValue =
          (selectedValue != null && uniqueOptions.contains(selectedValue))
              ? selectedValue
              : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 48,
                  child: DropdownButtonFormField<String>(
                    icon: Image.asset(
                      AppImage.arrow_down,
                      height: 12,
                      width: 12,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    initialValue: safeSelectedValue,
                    isExpanded: true,
                    hint: Text(
                      field.label,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                      ),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: uniqueOptions
                        .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ))
                        .toList(),
                    onChanged: _isLoadingOptions
                        ? null
                        : (v) {
                      setState(() {
                        _selectedByField[field.key] = v;
                        if (v != null) {
                          _selectedFieldIdByKey[field.key] = labelToId[v];
                        } else {
                          _selectedFieldIdByKey.remove(field.key);
                        }
                        // Update worksheet button visibility
                        if (field.key == 'worksheet_template_id') {
                          _hasWorksheetTemplate =
                              _m2oIntId(_selectedFieldIdByKey['worksheet_template_id']) !=
                                  null;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          if (field.key == 'vehicle_id') _buildLoadVehicleStockButton(),
        ],
      );
    }

    Widget _buildScheduleSelectField(_SelectFieldConfig field) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final options = _dedupOptions(_optionsByField[field.key] ?? []);
      final isDurationField = field.key == 'scheduled_duration';
      final isEndDateDisabledField = field.key == 'scheduled_date_end';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Label shown outside
            Text(
              field.label,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            SizedBox(
              height: 48,
              child: isDurationField
                  ? TextFormField(
                      controller: _controllerFor('scheduled_duration'),
                      onChanged: (v) => setState(() => _selectedByField[field.key] = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                        hintText: options.isNotEmpty ? options.first : field.label,
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      icon: Image.asset(
                        AppImage.arrow_down,
                        height: 12,
                        width: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      initialValue: _resolveDropdownInitialValue(
                        _selectedByField[field.key],
                        options,
                      ),
                      onTap: _isCalendarDateTimeField(field.key)
                          ? () => _pickDateTimeForField(field.key)
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                        hintText: options.isNotEmpty ? options.first : field.label,
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: options
                          .map((o) => DropdownMenuItem(
                                value: o,
                                child: Text(
                                  o,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: isEndDateDisabledField
                          ? null
                          : (v) {
                              if (_isCalendarDateTimeField(field.key)) return;
                              setState(() {
                                _selectedByField[field.key] = v;
                              });
                            },
                    ),
            ),
          ],
        ),
      );
    }

    List<String> _dedupOptions(List<String> source) {
      final out = <String>[];
      for (final v in source) {
        if (!out.contains(v)) out.add(v);
      }
      return out;
    }

    String? _resolveDropdownInitialValue(String? selected, List<String> options) {
      if (selected == null) return null;
      final count = options.where((e) => e == selected).length;
      return count == 1 ? selected : null;
    }

    Widget _buildPriority() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.orderPriority,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: List.generate(3, (i) {
              final index = i + 1;
              final active = index <= _priority;
              return IconButton(
                onPressed: () => setState(() => _priority = index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
                icon: Icon(
                  active ? Icons.star_rounded : Icons.star_border_rounded,
                  color: active ? const Color(0xFFFFCC00) : AppColors.textDisabled,
                  size:30,
                ),
              );
            }),
          ),
        ],
      );
    }

    Widget _buildTextArea({
      required String title,
      required String hint,
      required TextEditingController controller,
    }) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            minLines: 4,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildProcessTabs() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, i) {
            final label = _processTabs[i];
            final active = label == _selectedProcessTab;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              onSelected: (_) => setState(() => _selectedProcessTab = label),
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
              disabledColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
              avatar: null,
              showCheckmark: false,
              labelStyle: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: active
                    ? AppColors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: _processTabs.length,
        ),
      );
    }

    List<Widget> _buildSelectedProcessTabSection() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (_selectedProcessTab == AppStrings.orderTabInstructions) {
        return [
          _buildTextArea(
            title:  AppStrings.orderInstructionsTitle,
            hint: AppStrings.orderInstructionsHint,
            controller: _controllerFor('todo'),
          ),
          const SizedBox(height: 12),
          _buildTextArea(
            title:  AppStrings.orderLocationDirectionsTitle,
            hint: AppStrings.orderLocationDirectionsHint,
            controller: _controllerFor('location_directions'),
          ),
        ];
      }

      if (_selectedProcessTab == AppStrings.orderTabExecution) {
        return [
          Text(
            AppStrings.orderExecutionTitle,
            style: AppTextStyles.h1.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildExecutionDateTimeField(
            keyName: 'date_start',
            label:  AppStrings.orderActualStart,
          ),
          const SizedBox(height: 12),
          _buildExecutionDateTimeField(
            keyName: 'date_end',
            label: AppStrings.orderActualEnd),

          const SizedBox(height: 12),
          _buildExecutionDurationField(),
        ];
      }

      if (_selectedProcessTab == AppStrings.orderTabTimesheet) {
        return [
          Text(
        AppStrings.orderTimesheetTitle,
            style: AppTextStyles.h1.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTimesheetTable(),
        ];
      }

      if (_selectedProcessTab == AppStrings.orderTabMap) {
        return [
          Text(
        AppStrings.orderMapTitle,
            style: AppTextStyles.h1.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildMapBox(),
        ];
      }

      // Planning + any other tab keep existing planning section.
      return [
        Text(
          AppStrings.orderPlanningTitle,
          style: AppTextStyles.h1.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._scheduleFields.map(_buildScheduleSelectField),
        // const SizedBox(height: 18),
        // Text(
        //   AppStrings.orderRequestWorkers,
        //   style: AppTextStyles.h1.copyWith(
        //     fontWeight: FontWeight.w700,
        //     color: isDark ? Colors.white : AppColors.textPrimary,
        //   ),
        // ),
        // const SizedBox(height: 12),
        // _buildWorkerTable(),
      ];
    }

    Widget _buildMapBox() {
      final hasPoint = _mapLatitude != null && _mapLongitude != null;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.orderMapLocation,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_isMapLoading)
              const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_mapError.isNotEmpty)
              SizedBox(
                height: 240,
                child: Center(
                  child: Text(
                    _mapError,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                  ),
                ),
              )
            else if (!hasPoint)
              SizedBox(
                height: 240,
                child: Center(
                  child: Text(
                    _isExistingOrder ? AppStrings.orderMapNoLatLng : AppStrings.orderMapAfterSave,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 240,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(_mapLatitude!, _mapLongitude!),
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.example.field_service',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_mapLatitude!, _mapLongitude!),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (hasPoint) ...[
              const SizedBox(height: 8),
              Text(
                'Lat: ${_mapLatitude!.toStringAsFixed(6)}   Lng: ${_mapLongitude!.toStringAsFixed(6)}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildExecutionDateTimeField({
      required String keyName,
      required String label,
    }) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final ctrl = _controllerFor(keyName);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickExecutionDateTime(keyName),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                child: Text(
                  ctrl.text.isEmpty
                      ?  AppStrings.orderSelectDateTime
                      : ctrl.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: ctrl.text.isEmpty
                        ? (isDark ? AppColors.darkTextSecondary : AppColors.textHint)
                        : (isDark ? Colors.white : AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildExecutionDurationField() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final durationCtrl = _controllerFor('duration');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.orderActualDuration,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: TextFormField(
              controller: durationCtrl,
              enabled: false,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Widget _buildWorkerTable() {
    //   final isDark = Theme.of(context).brightness == Brightness.dark;
    //   return Container(
    //     decoration: BoxDecoration(
    //       color: isDark ? AppColors.darkSurface : AppColors.white,
    //       borderRadius: BorderRadius.circular(14),
    //       border: Border.all(
    //         color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
    //       ),
    //     ),
    //     child: ClipRRect(
    //       borderRadius: BorderRadius.circular(14),
    //       child: Column(
    //         children: [
    //           // ✅ Header row
    //           Container(
    //             color: isDark ? AppColors.darkSurface2 : const Color(0xFFEDEDED),
    //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    //             child: IntrinsicHeight(
    //               child: Row(
    //                 children: [
    //                   Expanded(
    //                     child: Text(
    //                       AppStrings.orderWorkerColName,
    //                       style: TextStyle(
    //                         fontWeight: FontWeight.w600,
    //                         fontSize: 15,
    //                         color: isDark ? Colors.white : AppColors.textPrimary,
    //                       ),
    //                     ),
    //                   ),
    //                   VerticalDivider(
    //                     color: isDark ? AppColors.darkBorder : Colors.white,
    //                     thickness: 1.5,
    //                     width: 16,
    //                   ),
    //                   Expanded(
    //                     child: Text(
    //                       AppStrings.orderWorkerColPhone,
    //                       style: TextStyle(
    //                         fontWeight: FontWeight.w600,
    //                         fontSize: 15,
    //                         color: isDark ? Colors.white : AppColors.textPrimary,
    //                       ),
    //                     ),
    //                   ),
    //                   VerticalDivider(
    //                     color: isDark ? AppColors.darkBorder : Colors.white,
    //                     thickness: 1.5,
    //                     width: 16,
    //                   ),
    //                   Expanded(
    //                     child: Text(
    //                       AppStrings.orderWorkerColEmail,
    //                       style: TextStyle(
    //                         fontWeight: FontWeight.w600,
    //                         fontSize: 15,
    //                         color: isDark ? Colors.white : AppColors.textPrimary,
    //                       ),
    //                     ),
    //                   ),
    //                   VerticalDivider(
    //                     color: isDark ? AppColors.darkBorder : Colors.white,
    //                     thickness: 1.5,
    //                     width: 16,
    //                   ),
    //                   Expanded(
    //                     child: Text(
    //                       AppStrings.orderWorkerColSchedule,
    //                       style: TextStyle(
    //                         fontWeight: FontWeight.w600,
    //                         fontSize: 15,
    //                         color: isDark ? Colors.white : AppColors.textPrimary,
    //                       ),
    //                       overflow: TextOverflow.ellipsis,
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           ),
    //
    //           // ✅ Add a line — right below header
    //           Align(
    //             alignment: Alignment.centerLeft,
    //             child: TextButton(
    //               onPressed: _addWorkerLine,
    //               child: Text(
    //                 AppStrings.orderAddLine,
    //                 style: AppTextStyles.labelLarge.copyWith(
    //                   color: AppColors.primary,
    //                   fontWeight: FontWeight.w600,
    //                 ),
    //               ),
    //             ),
    //           ),
    //
    //           // ✅ Worker rows with dividers
    //           if (_workers.isNotEmpty)
    //             ListView.separated(
    //               shrinkWrap: true,
    //               physics: const NeverScrollableScrollPhysics(),
    //               itemCount: _workers.length,
    //               separatorBuilder: (_, _) => const Divider(
    //                 height: 1,
    //                 color: Color(0xFFEDEDED),
    //               ),
    //               itemBuilder: (_, i) {
    //                 final row = _workers[i];
    //                 return Container(
    //                   color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
    //                   padding: const EdgeInsets.symmetric(
    //                     horizontal: 12,
    //                     vertical: 14,
    //                   ),
    //                   child: Row(
    //                     children: [
    //                       Expanded(
    //                         child: Text(
    //                           row.name,
    //                           style: TextStyle(
    //                             color: isDark ? Colors.white : AppColors.textPrimary,
    //                           ),
    //                         ),
    //                       ),
    //                       Expanded(
    //                         child: Text(
    //                           row.phone,
    //                           style: TextStyle(
    //                             color: isDark ? Colors.white : AppColors.textPrimary,
    //                           ),
    //                         ),
    //                       ),
    //                       Expanded(
    //                         child: Text(
    //                           row.email,
    //                           style: TextStyle(
    //                             color: isDark ? Colors.white : AppColors.textPrimary,
    //                           ),
    //                         ),
    //                       ),
    //                       Expanded(
    //                         child: Text(
    //                           row.schedule,
    //                           style: TextStyle(
    //                             color: isDark ? Colors.white : AppColors.textPrimary,
    //                           ),
    //                         ),
    //                       ),
    //                     ],
    //                   ),
    //                 );
    //               },
    //             ),
    //
    //           // ✅ Empty placeholder rows (visible when no workers) — like screenshot
    //           if (_workers.isEmpty) ...[
    //             const Divider(height: 1, color: Color(0xFFEDEDED)),
    //             const SizedBox(height: 44),
    //             const Divider(height: 1, color: Color(0xFFEDEDED)),
    //             const SizedBox(height: 44),
    //             const Divider(height: 1, color: Color(0xFFEDEDED)),
    //             const SizedBox(height: 44),
    //           ],
    //         ],
    //       ),
    //     ),
    //   );
    // }

    Widget _buildTimesheetTable() {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (_isLoadingOptions) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      // Fixed column widths — header and data must use same values
      const double wDate = 95;
      const double wType = 110;
      const double wEmp = 120;
      const double wDesc = 110;
      const double wTime = 70;
      const double wDel = 36;
      const double colGap = 8;
      const double tableWidth = wDate + wType + wEmp + wDesc + wTime + wDel
          + (colGap * 5) + 24; // 24 = horizontal padding (12*2)

      Widget headerCell(String text, double width) => SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  // ── Header ──
                  Container(
                    color: isDark ? AppColors.darkSurface2 : const Color(0xFFEDEDED),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        headerCell(AppStrings.orderTimesheetColDate, wDate),
                        const SizedBox(width: colGap),
                        headerCell(AppStrings.orderTimesheetColType, wType),
                        const SizedBox(width: colGap),
                        headerCell(AppStrings.orderTimesheetColEmployee, wEmp),
                        const SizedBox(width: colGap),
                        headerCell(AppStrings.orderTimesheetColDescription, wDesc),
                        const SizedBox(width: colGap),
                        headerCell(AppStrings.orderTimesheetColTimespent, wTime),
                        SizedBox(width: wDel),
                      ],
                    ),
                  ),

                  // ── Add a line ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _addTimesheetLine,
                      child: Text(
                        AppStrings.orderAddLine,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // ── Rows ──
                  if (_timesheetRows.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _timesheetRows.length,
                      separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      itemBuilder: (_, i) {
                        final row = _timesheetRows[i];
                        final typeOpts = _optionsByField['timesheet_type_id'] ?? const <String>[];
                        final empOpts = _optionsByField['employee_id'] ?? const <String>[];

                        String? safeType;
                        final storedTypeId = _timesheetRowTypeIds[i];
                        if (storedTypeId != null) {
                          final idx = _timesheetTypeIds.indexWhere(
                                (e) => _coerceOdooId(e) == storedTypeId,
                          );
                          if (idx >= 0 && idx < typeOpts.length) safeType = typeOpts[idx];
                        }
                        safeType ??= typeOpts.contains(row.timesheetType) ? row.timesheetType : null;

                        String? safeEmp;
                        final storedEmpId = _timesheetRowEmpIds[i];
                        if (storedEmpId != null) {
                          final idx = _employeeIds.indexWhere(
                                (e) => _coerceOdooId(e) == storedEmpId,
                          );
                          if (idx >= 0 && idx < empOpts.length) safeEmp = empOpts[idx];
                        }
                        safeEmp ??= empOpts.contains(row.employee) ? row.employee : null;

                        return Container(
                          key: ValueKey('ts_row_${i}_${row.odooId}'),
                          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              // Date
                              SizedBox(
                                width: wDate,
                                child: Text(
                                  row.date,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: colGap),

                              // Timesheet Type
                              SizedBox(
                                width: wType,
                                height: 34,
                                child: typeOpts.isEmpty
                                    ? Text('-', style: TextStyle(fontSize: 12, color: AppColors.textHint))
                                    : Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: safeType,
                                      isExpanded: true,
                                      isDense: true,
                                      icon: Image.asset(AppImage.arrow_down,height: 15,width: 15,),
                                      hint: Text('Select', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                                      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                                      items: typeOpts.map((o) => DropdownMenuItem(
                                        value: o,
                                        child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        final idx = typeOpts.indexOf(v);
                                        setState(() {
                                          _timesheetRows[i] = _timesheetRows[i].copyWithFields(timesheetType: v);
                                          if (idx >= 0 && idx < _timesheetTypeIds.length) {
                                            _timesheetRowTypeIds[i] = _coerceOdooId(_timesheetTypeIds[idx]);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: colGap),

                              // Employee
                              SizedBox(
                                width: wEmp,
                                height: 34,
                                child: empOpts.isEmpty
                                    ? Text('-', style: TextStyle(fontSize: 12, color: AppColors.textHint))
                                    : Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: safeEmp,
                                      isExpanded: true,
                                      isDense: true,
                                      icon: Image.asset(AppImage.arrow_down,height: 15,width: 15,),
                                      hint: Text('Select', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                                      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                                      items: empOpts.map((o) => DropdownMenuItem(
                                        value: o,
                                        child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        final idx = empOpts.indexOf(v);
                                        setState(() {
                                          _timesheetRows[i] = _timesheetRows[i].copyWithFields(employee: v);
                                          if (idx >= 0 && idx < _employeeIds.length) {
                                            _timesheetRowEmpIds[i] = _coerceOdooId(_employeeIds[idx]);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: colGap),

                              // Description
                              SizedBox(
                                width: wDesc,
                                height: 34,
                                child: TextFormField(
                                  key: ValueKey('desc_${i}_${row.odooId}'),
                                  initialValue: row.name == '-' ? '' : row.name,
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                    hintText: '-',
                                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textHint),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    _timesheetRows[i] = _timesheetRows[i].copyWithFields(name: v);
                                  },
                                ),
                              ),
                              const SizedBox(width: colGap),

                              // Time spent
                              SizedBox(
                                width: wTime,
                                height: 34,
                                child: TextFormField(
                                  key: ValueKey('time_${i}_${row.odooId}'),
                                  initialValue: row.unitAmountHours > 0 ? row.unitAmount : '',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                    hintText: '0.00',
                                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textHint),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final hours = double.tryParse(v) ?? 0.0;
                                    setState(() {
                                      _timesheetRows[i] = _timesheetRows[i].copyWithFields(unitAmountHours: hours);
                                    });
                                  },
                                ),
                              ),

                              // Delete
                              SizedBox(
                                width: wDel,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () => setState(() => _timesheetRows.removeAt(i)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  if (_timesheetRows.isEmpty) ...[
                    const Divider(height: 1, color: Color(0xFFEDEDED)),
                    const SizedBox(height: 44),
                    const Divider(height: 1, color: Color(0xFFEDEDED)),
                    const SizedBox(height: 44),
                    const Divider(height: 1, color: Color(0xFFEDEDED)),
                    const SizedBox(height: 44),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget _buildChatterTabs() {
      if (!_isExistingOrder || _existingOrderId == null) {
        return const SizedBox.shrink();
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SizedBox(
        height: 480,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ChatterWidget(
              model: 'fsm.order',
              recordId: _existingOrderId!,
            ),
          ),
        ),
      );
    }


    /// Shows the "Load Vehicle Stock" button only when vehicle_id is selected.
    Widget _buildLoadVehicleStockButton() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final vehicleSelected = _selectedFieldIdByKey['vehicle_id'] != null;
      if (!vehicleSelected) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: 163,
          height: 40,
          child: OutlinedButton(
            onPressed: _isLoadingVehicleStock ? null : _onLoadVehicleStockPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFF1F1F1),

              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoadingVehicleStock
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.orderVehicleStockLoadButton,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> _onLoadVehicleStockPressed() async {
      if (!mounted) return;
      setState(() => _isLoadingVehicleStock = true);
      try {
        final vehicleIdRaw = _selectedFieldIdByKey['vehicle_id'];
        final vehicleId = vehicleIdRaw is int
            ? vehicleIdRaw
            : int.tryParse(vehicleIdRaw?.toString() ?? '');

        // Fetch wizard defaults and product list concurrently
        final futures = await Future.wait<dynamic>([
          _existingOrderId != null
              ? _repository.fetchVehicleStockWizardDefaults(
              fsmOrderId: _existingOrderId!)
              : Future<Map<String, dynamic>>.value(<String, dynamic>{}),
          vehicleId != null
              ? _repository.fetchVehicleStockProducts(vehicleId: vehicleId)
              : Future<List<Map<String, dynamic>>>.value(
              const <Map<String, dynamic>>[]),
        ]);

        if (!mounted) return;
        setState(() {
          _vehicleStockWizardDefaults =
              futures[0] as Map<String, dynamic>? ?? {};
          _vehicleStockProducts =
              futures[1] as List<Map<String, dynamic>>? ?? [];
          _isLoadingVehicleStock = false;
        });
        await _showLoadVehicleStockDialog();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoadingVehicleStock = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderVehicleStockLoadFailed}$e')),
        );
      }
    }

    Future<void> _showLoadVehicleStockDialog() async {
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Keep quant-based data for qty/lot info (stock screen untouched)
      final quantOptions = _vehicleStockProducts
          .map(_vehicleProductOptionFromRaw)
          .whereType<_VehicleProductOption>()
          .where((o) => o.id > 0)
          .toList();

      // Build a map of quantOptions by product id for qty/lot lookup
      final quantMap = <int, _VehicleProductOption>{
        for (final q in quantOptions) q.id: q,
      };

      // Fetch ALL products for the dropdown separately
      List<_VehicleProductOption> productOptions = quantOptions; // fallback
      try {
        final allRaw = await _repository.fetchAllProductsForDropdown();
        if (allRaw.isNotEmpty) {
          final seen = <int>{};
          productOptions = allRaw.map((e) {
            final id = e['id'];
            final pid = id is int ? id : int.tryParse('$id');
            if (pid == null || pid <= 0) return null;
            if (!seen.add(pid)) return null;
            final name = e['name']?.toString() ?? 'Product #$pid';
            // Use quant qty/lot data if available, else zero
            final quant = quantMap[pid];
            return _VehicleProductOption(
              id: pid,
              name: name,
              availableQty: quant?.availableQty ?? 0.0,
              lotId: quant?.lotId,
              lotName: quant?.lotName ?? '',
            );
          }).whereType<_VehicleProductOption>().toList();
        }
      } catch (_) {
        // fallback to quantOptions already set
      }

      final rows = <_VehicleStockRow>[];
      final defaults = _vehicleStockWizardDefaults;
      bool isSubmitting = false;

      final fsmOrderLabel =
      (defaults['_fsm_order_name']?.toString().isNotEmpty ?? false)
          ? defaults['_fsm_order_name'].toString()
          : (_m2oLabelFrom(defaults['fsm_order_id']) ??
          _selectedByField['name'] ??
          (_existingOrderId != null ? 'Order #$_existingOrderId' : 'New Order'));
      final vehicleLabel =
          _selectedByField['vehicle_id'] ?? _m2oLabelFrom(defaults['vehicle_id']) ?? '-';
      final destLabel = _m2oLabelFrom(defaults['location_dest_id']) ?? '-';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                title: Text(
                  AppStrings.orderVehicleStockTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogReadonlyField(AppStrings.orderVehicleStockFsmOrder, fsmOrderLabel),
                        const SizedBox(height: 10),
                        _dialogReadonlyField(AppStrings.orderVehicleStockVehicle, vehicleLabel),
                        const SizedBox(height: 10),
                        _dialogReadonlyField(AppStrings.orderVehicleStockDest, destLabel),
                        const SizedBox(height: 18),
                        _buildVehicleStockTable(
                          rows: rows,
                          productOptions: productOptions,
                          setDialogState: setDialogState,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      AppStrings.orderCancel,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                      setDialogState(() => isSubmitting = true);
                      final keepOpen = await _onCreateTransferPressed(rows);
                      if (ctx.mounted && !keepOpen) {
                        Navigator.of(ctx).pop();
                      }
                      if (ctx.mounted) {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
                    child: isSubmitting
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        :  Text(
                      AppStrings.orderVehicleStockCreateTransfer,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Widget _buildVehicleStockTable({
      required List<_VehicleStockRow> rows,
      required List<_VehicleProductOption> productOptions,
      required StateSetter setDialogState,
    }) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      const productWidth = 280.0;
      const availWidth = 90.0;
      const qtyWidth = 150.0;
      const lotWidth = 160.0;
      const deleteWidth = 36.0;
      final tableWidth = productWidth + availWidth + qtyWidth + lotWidth + deleteWidth + 40;

      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              // ── Heading ──
              Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.orderVehicleStockProducts,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // ── Header row ──
                      Container(
                        color: isDark ? AppColors.darkSurface2 : const Color(0xFFEDEDED),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: productWidth,
                              child: Text(AppStrings.orderVehicleStockProducts,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  )),
                            ),
                            SizedBox(width: 10),
                            SizedBox(
                              width: availWidth,
                              child: Text(AppStrings.orderVehicleStockAvailQty,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  )),
                            ),
                            SizedBox(width: 10),
                            SizedBox(
                              width: qtyWidth,
                              child: Text(AppStrings.orderVehicleStockQuantity,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  )),
                            ),
                            SizedBox(width: 10),
                            SizedBox(
                              width: lotWidth,
                              child: Text(AppStrings.orderVehicleStockLot,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  )),
                            ),
                            SizedBox(width: deleteWidth),
                          ],
                        ),
                      ),
                      // ── Rows ──
                      if (rows.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFEDEDED)),
                          itemBuilder: (_, i) {
                            final row = rows[i];
                            return _buildVehicleStockRowWidget(
                              index: i,
                              rows: rows,
                              row: row,
                              productOptions: productOptions,
                              setDialogState: setDialogState,
                              onDelete: () => setDialogState(() => rows.removeAt(i)),
                              productWidth: productWidth,
                              availWidth: availWidth,
                              qtyWidth: qtyWidth,
                              lotWidth: lotWidth,
                              deleteWidth: deleteWidth,
                            );
                          },
                        )
                      else ...[
                        const Divider(height: 1, color: Color(0xFFEDEDED)),
                        const SizedBox(height: 36),
                        const Divider(height: 1, color: Color(0xFFEDEDED)),
                        const SizedBox(height: 36),
                      ],
                      // ── "Add a line" inside table, below rows ──
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setDialogState(() {
                              rows.add(_VehicleStockRow(
                                productId: 0,
                                productName: '',
                                availableQty: 0,
                                quantity: 1,
                                lotId: null,
                                lotName: '',
                              ));
                            });
                          },
                          child: Text(
                            AppStrings.orderAddLine,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (productOptions.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              AppStrings.orderVehicleStockNoProducts,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : Colors.grey,
                              ),
                            ),
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

    Widget _buildVehicleStockRowWidget({
      required int index,
      required List<_VehicleStockRow> rows,
      required _VehicleStockRow row,
      required List<_VehicleProductOption> productOptions,
      required StateSetter setDialogState,
      required VoidCallback onDelete,
      double productWidth = 280.0,
      double availWidth = 90.0,
      double qtyWidth = 150.0,
      double lotWidth = 160.0,
      double deleteWidth = 36.0,
    }) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final qtyCtrl =
      TextEditingController(text: row.quantity.toStringAsFixed(0));

      return Container(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: row.productId > 0 ? row.productId : null,
                hint: Text(
                  AppStrings.orderVehicleStockSelect,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                  ),
                ),
                menuMaxHeight: 320,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: productOptions
                    .map((o) => DropdownMenuItem<int>(
                  value: o.id,
                  child: Text(o.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      )),
                ))
                    .toList(),
                // REPLACE
                onChanged: (selectedId) async {
                  if (selectedId == null) return;
                  final opt =
                  productOptions.firstWhere((o) => o.id == selectedId);
                  final freshQty = await _repository.fetchProductAvailableQty(
                    productId: selectedId,
                    vehicleId: _m2oIntId(_vehicleStockWizardDefaults['vehicle_id']) ??
                        _m2oIntId(_selectedFieldIdByKey['vehicle_id']),
                  );
                  setDialogState(() {
                    rows[index] = _VehicleStockRow(
                      productId: selectedId,
                      productName: opt.name,
                      availableQty: freshQty > 0 ? freshQty : opt.availableQty,
                      quantity: 1,
                      lotId: opt.lotId,
                      lotName: opt.lotName,
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFEFF8EF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  row.availableQty.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 165,
              child: Row(
                children: [
                  InkWell(
                    onTap: row.quantity > 1
                        ? () => setDialogState(() {
                      rows[index] = _VehicleStockRow(
                        productId: row.productId,
                        productName: row.productName,
                        availableQty: row.availableQty,
                        quantity: row.quantity - 1,
                        lotId: row.lotId,
                        lotName: row.lotName,
                      );
                    })
                        : null,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: row.quantity > 1
                            ? AppColors.primary
                            : const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.remove,
                          color: Colors.white, size: 14),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextFormField(
                        controller: qtyCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v) ?? 1;
                          final clamped = parsed.clamp(
                            1.0,
                            row.availableQty > 0 ? row.availableQty : double.maxFinite,
                          ).toDouble();
                          setDialogState(() {
                            rows[index] = _VehicleStockRow(
                              productId: row.productId,
                              productName: row.productName,
                              availableQty: row.availableQty,
                              quantity: clamped,
                              lotId: row.lotId,
                              lotName: row.lotName,
                            );
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  InkWell(
                    onTap: row.availableQty <= 0 ||
                        row.quantity < row.availableQty
                        ? () => setDialogState(() {
                      rows[index] = _VehicleStockRow(
                        productId: row.productId,
                        productName: row.productName,
                        availableQty: row.availableQty,
                        quantity: row.quantity + 1,
                        lotId: row.lotId,
                        lotName: row.lotName,
                      );
                    })
                        : null,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: (row.availableQty <= 0 ||
                            row.quantity < row.availableQty)
                            ? AppColors.primary
                            : const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child:
                      const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 190,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
                  ),
                ),
                child: Text(
                  row.lotName.isNotEmpty ? row.lotName : '-',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      );
    }

    Widget _dialogReadonlyField(String label, String value) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                )),
          ),
        ],
      );
    }

    Future<bool> _onCreateTransferPressed(List<_VehicleStockRow> rows) async {
      final validRows = rows.where((r) => r.productId > 0 && r.quantity > 0).toList();
      if (validRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(AppStrings.orderTransferAddLine),
          ),
        );
        return true;
      }

      // Prefer selected vehicle, fallback to wizard defaults (vehicle from FSM order)
      final vehicleIdRaw = _selectedFieldIdByKey['vehicle_id'] ??
          _vehicleStockWizardDefaults['vehicle_id'];
      final vehicleId = _m2oIntId(vehicleIdRaw);

      final destRaw = _vehicleStockWizardDefaults['location_dest_id'];
      final locationDestId = _m2oIntId(destRaw);

      final fsmOrderId = _existingOrderId;

      if (fsmOrderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(AppStrings.orderTransferSaveFirst),
          ),
        );
        return true;
      }

      if (locationDestId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(AppStrings.orderTransferNoDestination),
          ),
        );
        return true;
      }

      try {
        final result = await _repository.createVehicleStockTransfer(
          fsmOrderId: fsmOrderId,
          vehicleId: vehicleId,
          locationDestId: locationDestId,
          lines: validRows.map((r) => r.toPayload()).toList(),
        );
        if (!mounted) return true;
        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Create transfer failed.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.queued
                ? AppStrings.orderTransferQueued
                : result.pickingId != null
                ? 'Transfer created successfully (Picking #${result.pickingId}).'
                : AppStrings.orderTransferSuccess),
            backgroundColor: result.queued ? Colors.orange : Colors.green,
          ),
        );
        return false;
      } catch (e) {
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderTransferFailedDetail}$e')),
        );
        return true;
      }
    }

    // Helper: extract int id from Odoo many2one [id, label]
    int? _m2oIntId(dynamic v) {
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is int) return first;
        if (first is num) return first.toInt();
        return int.tryParse(first.toString());
      }
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    String? _m2oLabelFrom(dynamic v) {
      if (v is List && v.length >= 2) return v[1]?.toString();
      return null;
    }

    void _putM2oIfSelectedForSave(Map<String, dynamic> values, String key) {
      final idRaw = _selectedFieldIdByKey[key];
      if (idRaw == null) return;
      final id = _m2oIntId(idRaw is List ? idRaw : <dynamic>[idRaw]);
      if (id == null || id <= 0) return;
      final label = _selectedByField[key]?.toString().trim();
      if (label != null && label.isNotEmpty) {
        values[key] = <dynamic>[id, label];
      } else {
        values[key] = idRaw is List ? idRaw : id;
      }
    }

    _VehicleProductOption? _vehicleProductOptionFromRaw(Map<String, dynamic> e) {
      final pid = e['product_id'];
      int? id;
      String? name;
      if (pid is List && pid.length >= 2) {
        id = pid[0] is int ? pid[0] as int : int.tryParse('${pid[0]}');
        name = pid[1]?.toString();
      } else if (pid is int) {
        id = pid;
        name = e['name']?.toString() ?? e['display_name']?.toString();
      }
      if (id == null || id <= 0) return null;
      final resolvedName = (name ?? '').trim().isNotEmpty
          ? name!.trim()
          : 'Product #$id';
      return _VehicleProductOption(
        id: id,
        name: resolvedName,
        availableQty: _toDouble(e['inventory_quantity_auto_apply']) ?? 0,
        lotId: _lotIdFrom(e['lot_id']),
        lotName: _lotNameFrom(e['lot_id']),
      );
    }

    int? _lotIdFrom(dynamic v) {
      if (v == null || v == false) return null;
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is int) return first;
        return int.tryParse(first.toString());
      }
      if (v is int) return v;
      return null;
    }

    String _lotNameFrom(dynamic v) {
      if (v == null || v == false) return '';
      if (v is List && v.length >= 2) return v[1]?.toString() ?? '';
      return '';
    }

    double? _toDouble(dynamic v) {
      if (v == null || v == false) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    Widget _buildActivity() {
      return const SizedBox.shrink();
    }

    void _addWorkerLine() {
      setState(() {
        _workers.add(
          _WorkerRow(
            name: 'Worker ${_workers.length + 1}',
            phone: '-',
            email: '-',
            schedule: '-',
          ),
        );
      });
    }

    void _addTimesheetLine() {
      final typeOpts = _optionsByField['timesheet_type_id'] ?? const <String>[];
      final empOpts = _optionsByField['employee_id'] ?? const <String>[];

      // Pre-select first type option as default
      String defaultType = '-';
      if (typeOpts.isNotEmpty) defaultType = typeOpts.first;

      // Pre-select employee matching logged-in user, fallback to first
      String defaultEmp = '-';
      if (empOpts.isNotEmpty) {
        // Try to match default employee from existing timesheet rows
        if (_defaultEmployeeOdooId != null) {
          final idx = _employeeIds.indexWhere(
                (e) => _coerceOdooId(e) == _defaultEmployeeOdooId,
          );
          if (idx >= 0 && idx < empOpts.length) {
            defaultEmp = empOpts[idx];
          } else {
            defaultEmp = empOpts.first;
          }
        } else {
          defaultEmp = empOpts.first;
        }
      }

      setState(() {
        _timesheetRows.add(
          _TimesheetRow(
            odooId: null,
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            timesheetType: defaultType,
            employee: defaultEmp,
            name: '',
            unitAmountHours: 0,
          ),
        );
      });
    }


    TextEditingController _controllerFor(String key) {
      return _textControllers.putIfAbsent(key, TextEditingController.new);
    }

    Future<void> _onSavePressed() async {
      final requiredFields = <String>[
        'location_id',
      ];
      for (final key in requiredFields) {
        if (_selectedFieldIdByKey[key] == null) {
          final label = _primaryFields.firstWhere((f) => f.key == key).label;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.orderSelectRequired}$label')),
          );
          return;
        }
      }

      setState(() => _isSaving = true);
      try {
        final values = <String, dynamic>{};
        _putM2oIfSelectedForSave(values, 'partner_id');
        _putM2oIfSelectedForSave(values, 'template_id');
        _putIfNotNull(values, 'type', _selectedFieldIdByKey['type']);
        _putM2oIfSelectedForSave(values, 'location_id');
        _putM2oIfSelectedForSave(values, 'person_id');
        _putM2oIfSelectedForSave(values, 'vehicle_id');
        _putM2oIfSelectedForSave(values, 'company_id');
        // After the company_id line:
        _putM2oIfSelectedForSave(values, 'worksheet_template_id');
        values['priority'] = _priority.toString();

        _putIfNotBlank(values, 'description', _controllerFor('description').text);
        _putIfNotBlank(values, 'resolution', _controllerFor('resolution').text);
        _putIfNotBlank(
          values,
          'request_early',
          _scheduleDatetimeForOdooWrite(_selectedByField['request_early']),
        );
        _putIfNotBlank(
          values,
          'request_late',
          _scheduleDatetimeForOdooWrite(_selectedByField['request_late']),
        );
        _putIfNotBlank(
          values,
          'scheduled_date_start',
          _scheduleDatetimeForOdooWrite(_selectedByField['scheduled_date_start']),
        );
        _putIfNotBlank(
          values,
          'scheduled_duration',
          _controllerFor('scheduled_duration').text.trim(),
        );
        _putIfNotBlank(
          values,
          'scheduled_date_end',
          _scheduleDatetimeForOdooWrite(_selectedByField['scheduled_date_end']),
        );
        _putIfNotBlank(values, 'todo', _controllerFor('todo').text);
        _putIfNotBlank(values, 'location_directions', _controllerFor('location_directions').text);
        _putIfNotBlank(values, 'date_start', _executionControllerForOdooWrite('date_start'));
        _putIfNotBlank(values, 'date_end', _executionControllerForOdooWrite('date_end'));
        _putIfNotBlank(values, 'duration', _controllerFor('duration').text);

        if (_isExistingOrder && _existingOrderId != null) {
          await _repository.updateOrder(_existingOrderId!, values);
        } else {
          await _repository.createOrder(values);
        }

        if (Get.isRegistered<OrderController>()) {
          await Get.find<OrderController>().loadOrders();
        } else {
          AppLogger.warning(
            'OrderController not registered after save — list/kanban will not '
            'refresh until the Orders tab loads the controller.',
            tag: 'ORDER_CREATE',
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isExistingOrder ? AppStrings.orderUpdateSuccess : AppStrings.orderSaveSuccess)),
        );
        // After existing save logic, before Get.back(), add:
        if (_isExistingOrder && _existingOrderId != null) {
          for (final row in _timesheetRows.where((r) => r.odooId == null)) {
            final typeIdx = (_optionsByField['timesheet_type_id'] ?? []).indexOf(row.timesheetType);
            final empIdx = (_optionsByField['employee_id'] ?? []).indexOf(row.employee);
            final typeId = typeIdx >= 0 && typeIdx < _timesheetTypeIds.length
                ? _coerceOdooId(_timesheetTypeIds[typeIdx])
                : null;
            final empId = empIdx >= 0 && empIdx < _employeeIds.length
                ? _coerceOdooId(_employeeIds[empIdx])
                : null;

            final vals = <String, dynamic>{
              OdooOrdersConfig.timesheetCreateOrderField: _existingOrderId!,
              'name': row.name.isEmpty ? AppStrings.orderTimesheetWorkLog : row.name,
              'unit_amount': row.unitAmountHours,
              'date': row.date,
              if (typeId != null) 'timesheet_type_id': typeId,
              if (empId != null) 'employee_id': empId,
            };
            await _repository.createTimesheetLine(vals);
          }
          await _reloadTimesheetsForOrder(_existingOrderId!);
        }
        Get.back();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderSaveFailed}$e')),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

    void _onCancelPressed() {
      Get.back();
    }

    Future<void> _refreshSaleOrderAndInvoiceFlags() async {
      if (!_isExistingOrder || _existingOrderId == null) {
        if (mounted) {
          setState(() {
            _hasLinkedSaleOrder = false;
            _hasCustomerInvoice = false;
          });
        }
        return;
      }
      final oid = _existingOrderId!;
      try {
        final so = await _repository.fetchSaleOrderForFsmOrder(oid);
        if (!mounted) return;
        int? soId;
        if (so != null) {
          final rid = so['id'];
          soId = rid is int ? rid : int.tryParse('$rid');
        }
        if (soId != null && soId > 0) {
          var hasInv = false;
          final inv = await _repository.fetchLatestInvoiceForSaleOrder(soId);
          if (!mounted) return;
          if (inv != null) {
            final iid = inv['id'];
            final id = iid is int ? iid : int.tryParse('$iid');
            hasInv = id != null && id > 0;
          }
          setState(() {
            _hasLinkedSaleOrder = true;
            _hasCustomerInvoice = hasInv;
          });
        } else {
          setState(() {
            _hasLinkedSaleOrder = false;
            _hasCustomerInvoice = false;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _hasLinkedSaleOrder = false;
          _hasCustomerInvoice = false;
        });
      }
    }

    Future<void> _openStockScreen() async {
      final orderId = _existingOrderId;
      if (orderId == null) return;
      try {
        final vehicleId =
            _m2oIntId(_selectedFieldIdByKey['vehicle_id']) ??
                _m2oIntId(_vehicleStockWizardDefaults['vehicle_id']);
        final items = await _repository.fetchVehicleStockItemsForOrder(
          fsmOrderId: orderId,
          vehicleIdOverride: vehicleId,
        );
        if (!mounted) return;
        if (items.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.orderStockNone)),
          );
          return;
        }
        await Get.to(() => _OrderStockView(items: items));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderStockOpenFailed}$e')),
        );
      }
    }

    Future<void> _initFormData() async {
      try {
        await _loadPrimaryFieldOptions();
        // Check worksheet module in parallel with stage/order loading
        final worksheetCheck = _repository.checkWorksheetModuleInstalled();
        if (_isExistingOrder) {
          await _loadAvailableStages();
          await _loadExistingOrderData();
        }
        final installed = await worksheetCheck;
        if (mounted) setState(() => _worksheetModuleInstalled = installed);
      } finally {
        if (mounted) {
          setState(() => _isBootstrapping = false);
        }
      }
    }

    Widget _buildBootstrapPlaceholder(bool isDark) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Image.asset(
                    AppImage.back,
                    width: 25,
                    height: 25,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.navOrder,
                    style: AppTextStyles.h1.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _isExistingOrder
                          ? AppStrings.orderLoadingOrderDetails
                          : AppStrings.orderLoadingForm,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Future<void> _loadAvailableStages() async {
      try {
        final board = await _repository.fetchKanban();
        final stages = board.stages
            .map((s) => <String, dynamic>{'id': s.id, 'name': s.name})
            .toList();
        if (!mounted) return;
        setState(() => _availableStages = stages);
      } catch (_) {
        // Keep current UI behavior intact if stage list fails.
      }
    }

    Future<void> _loadExistingOrderData() async {
      try {
        final id = _existingOrderId;
        if (id == null) return;
        setState(() {
          _isMapLoading = true;
          _mapError = '';
        });
        final raw = await _repository.fetchOrderById(
          id,
          fields: <String>[
            'id',
            'is_closed',
            'stage_id',
            'partner_id',
            'template_id',
            'type',
            'location_id',
            'person_id',
            'vehicle_id',
            'company_id',
            'worksheet_template_id',
            'priority',
            'description',
            'resolution',
            'request_early',
            'request_late',
            'scheduled_date_start',
            'scheduled_duration',
            'scheduled_date_end',
            'todo',
            'location_directions',
            'date_start',
            'date_end',
            'duration',
          ],
        );
        if (!mounted) return;
        setState(() {
          _applyExistingSelection('partner_id', raw['partner_id']);
          _applyExistingSelection('template_id', raw['template_id']);
          _applyExistingSelection('type', raw['type']);
          _applyExistingSelection('location_id', raw['location_id']);
          _applyExistingSelection('person_id', raw['person_id']);
          _applyExistingSelection('vehicle_id', raw['vehicle_id']);
          _applyExistingSelection('company_id', raw['company_id']);
          _applyExistingSelection('worksheet_template_id', raw['worksheet_template_id']);
// Update worksheet button state after loading
          _hasWorksheetTemplate =
              _m2oIntId(_selectedFieldIdByKey['worksheet_template_id']) != null;
          _isClosed = _asBool(raw['is_closed']);
          _currentStageId = _m2oIntId(raw['stage_id']);
          _currentStageName = _m2oLabelFrom(raw['stage_id']) ?? '';
          final pr = raw['priority'];
          if (pr is String) {
            _priority = int.tryParse(pr)?.clamp(0, 3) ?? 0;
          } else if (pr is num) {
            _priority = pr.toInt().clamp(0, 3);
          } else {
            _priority = int.tryParse('${pr ?? 0}')?.clamp(0, 3) ?? 0;
          }
          _controllerFor('description').text = _stripHtml(_asText(raw['description']));
          _controllerFor('resolution').text = _stripHtml(_asText(raw['resolution']));
          _controllerFor('todo').text = _stripHtml(_asText(raw['todo']));
          _controllerFor('location_directions').text =
              (raw['location_directions'] ?? '').toString();
          _controllerFor('date_start').text = _formatDateTimeOrBlank(raw['date_start']);
          _controllerFor('date_end').text = _formatDateTimeOrBlank(raw['date_end']);
          _controllerFor('duration').text = _asText(raw['duration']);
          _mergeScheduleFromOdoo('request_early', raw['request_early']);
          _mergeScheduleFromOdoo('request_late', raw['request_late']);
          _mergeScheduleFromOdoo('scheduled_date_start', raw['scheduled_date_start']);
          _mergeScheduleFromOdoo('scheduled_duration', raw['scheduled_duration']);
          _mergeScheduleFromOdoo('scheduled_date_end', raw['scheduled_date_end']);
        });
        await _loadMapCoordinatesForOrder(id);
        await _reloadTimesheetsForOrder(id);
        await _refreshSaleOrderAndInvoiceFlags();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isMapLoading = false;
          _mapError = AppStrings.orderMapCoordError;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderPrefillError}$e')),
        );
      }
    }

    Future<void> _loadMapCoordinatesForOrder(int orderId) async {
      try {
        final coords = await _repository.fetchOrderMapCoordinates(orderId);
        if (!mounted) return;
        setState(() {
          _mapLatitude = coords?.latitude;
          _mapLongitude = coords?.longitude;
          _isMapLoading = false;
          _mapError = '';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isMapLoading = false;
          _mapError = AppStrings.orderMapResolveError;
        });
      }
    }

    String? _labelForPrimaryOptionId(String key, dynamic id) {
      final options = _optionsByField[key] ?? const <String>[];
      final ids = _primaryOptionIds[key] ?? const <dynamic>[];
      final idInt = _m2oIntId(id is List ? id : <dynamic>[id]);
      for (var i = 0; i < options.length && i < ids.length; i++) {
        if (_m2oIntId(ids[i]) == idInt) return options[i];
      }
      return null;
    }

    void _applyExistingSelection(String key, dynamic rawValue) {
      dynamic idValue;
      String? label;
      if (rawValue is List && rawValue.isNotEmpty) {
        idValue = rawValue.first;
        if (rawValue.length >= 2) label = rawValue[1]?.toString();
      } else if (rawValue != null && rawValue != false) {
        idValue = _m2oIntId(rawValue);
        label = idValue != null ? _labelForPrimaryOptionId(key, idValue) : null;
      }
      if (idValue == null) return;
      _selectedFieldIdByKey[key] = idValue;
      if (label != null && label.isNotEmpty) {
        final opts = _optionsByField[key] ?? const <String>[];
        if (!opts.contains(label)) {
          _optionsByField[key] = <String>[label, ...opts];
        }
        _selectedByField[key] = label;
      }
    }

    String _asText(dynamic v) {
      if (v == null || v == false) return '';
      return v.toString();
    }

    bool _asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v == null) return false;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1';
    }

    String _stripHtml(String? html) {
      if (html == null || html.isEmpty) return '';
      return html
          .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    DateTime? _parseOdooDateTime(dynamic raw) {
      if (raw == null || raw == false) return null;
      if (raw is List) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      final iso = s.replaceFirst(' ', 'T');
      if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(iso)) {
        return DateTime.tryParse(iso)?.toLocal();
      }
      if (OdooOrdersConfig.odooNaiveDatetimesAreUtc) {
        final m = RegExp(
          r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
        ).firstMatch(s.length >= 19 ? s.substring(0, 19) : s);
        if (m != null) {
          final utc = DateTime.utc(
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.parse(m.group(3)!),
            int.parse(m.group(4)!),
            int.parse(m.group(5)!),
            int.parse(m.group(6)!),
          );
          return utc.toLocal();
        }
      }
      return DateTime.tryParse(iso);
    }

    String _formatDateTimeUtc(DateTime utc) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
          '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
    }

    String? _scheduleDatetimeForOdooWrite(String? uiValue) {
      final v = uiValue?.trim();
      if (v == null || v.isEmpty) return null;
      if (!OdooOrdersConfig.writeScheduleDatetimesAsUtc) return v;
      final dt = _tryParseDateTime(v);
      if (dt == null) return v;
      return _formatDateTimeUtc(dt.toUtc());
    }

    String? _executionControllerForOdooWrite(String controllerKey) {
      final t = _controllerFor(controllerKey).text.trim();
      if (t.isEmpty) return null;
      if (!OdooOrdersConfig.writeScheduleDatetimesAsUtc) return t;
      final dt = _tryParseDateTime(t);
      if (dt == null) return t;
      return _formatDateTimeUtc(dt.toUtc());
    }

    int? _coerceOdooId(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    int? _m2oIdFromOdoo(dynamic v) {
      if (v is List && v.isNotEmpty) return _coerceOdooId(v.first);
      return null;
    }

    double _hoursFromDurationForOdoo(Duration d) {
      return d.inMicroseconds / Duration.microsecondsPerHour;
    }

    void _prependUniqueOption(String key, String value) {
      if (value.isEmpty) return;
      final list = List<String>.from(_optionsByField[key] ?? <String>[]);
      list.remove(value);
      _optionsByField[key] = <String>[value, ...list];
      _selectedByField[key] = value;
    }

    void _mergeScheduleFromOdoo(String key, dynamic raw) {
      if (key == 'scheduled_duration') {
        _setScheduledDurationFromOdoo(raw);
        return;
      }
      final dt = _parseOdooDateTime(raw);
      if (dt == null) {
        _selectedByField[key] = null;
        return;
      }
      _prependUniqueOption(key, _formatDateTime(dt));
    }

    void _setScheduledDurationFromOdoo(dynamic raw) {
      if (raw == null || raw == false) {
        _controllerFor('scheduled_duration').text = '';
        _selectedByField['scheduled_duration'] = '';
        return;
      }
      final n = raw is num ? raw : num.tryParse(raw.toString());
      final text = n != null ? n.toDouble().toStringAsFixed(2) : raw.toString();
      _controllerFor('scheduled_duration').text = text;
      _selectedByField['scheduled_duration'] = text;
    }

    dynamic _idForTimesheetDropdown(String fieldKey, String label) {
      if (label.isEmpty || label == '-') return null;
      final opts = _optionsByField[fieldKey] ?? const <String>[];
      final idx = opts.indexOf(label);
      if (idx < 0) return null;
      final ids = fieldKey == 'timesheet_type_id' ? _timesheetTypeIds : _employeeIds;
      if (idx >= ids.length) return null;
      return ids[idx];
    }

    Future<void> _persistTimesheetRowsCache() async {
      final id = _existingOrderId;
      if (id == null) return;
      await _repository.saveTimesheetsCache(
        id,
        _timesheetRows.map((r) => r.toOdooCacheLite()).toList(),
      );
    }

    Future<void> _reloadTimesheetsForOrder(int orderId) async {
      try {
        final localOnly = _timesheetRows.where((r) => r.odooId == null).toList();
        final maps = await _repository.fetchTimesheetsForOrder(orderId);
        if (!mounted) return;

        // Store raw Odoo IDs for type and employee
        final typeIdByOdooId = <int, int?>{}; // odooId → typeId
        final empIdByOdooId = <int, int?>{};  // odooId → empId

        for (final m in maps) {
          _defaultTimesheetTypeOdooId ??= _m2oIdFromOdoo(m['timesheet_type_id']);
          _defaultEmployeeOdooId ??= _m2oIdFromOdoo(m['employee_id']);

          final oid = m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}');
          if (oid != null) {
            typeIdByOdooId[oid] = _m2oIdFromOdoo(m['timesheet_type_id']);
            empIdByOdooId[oid] = _m2oIdFromOdoo(m['employee_id']);
          }
        }

        setState(() {
          _timesheetRows
            ..clear()
            ..addAll(maps.map(_TimesheetRow.fromOdooMap))
            ..addAll(localOnly);

          // Map row index → odoo ids
          _timesheetRowTypeIds.clear();
          _timesheetRowEmpIds.clear();
          for (var i = 0; i < _timesheetRows.length; i++) {
            final oid = _timesheetRows[i].odooId;
            if (oid != null) {
              _timesheetRowTypeIds[i] = typeIdByOdooId[oid];
              _timesheetRowEmpIds[i] = empIdByOdooId[oid];
            }
          }
        });
      } catch (_) {}
    }


    void _onTimerPauseResumePressed() {
      if (!_isExistingOrder) return;
      if (_isTimerRunning) {
        _timer?.cancel();
        setState(() => _isTimerRunning = false);
        return;
      }
      _timer?.cancel();
      setState(() => _isTimerRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isTimerRunning) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    }

    void _onTimerStartPressed() {
      if (!_isExistingOrder) return;
      if (_elapsed == Duration.zero && !_isTimerRunning) {
        _onTimerPauseResumePressed();
      }
    }

    Future<void> _onTimerStopPressed() async {
      if (!_isExistingOrder) return;
      _timer?.cancel();
      setState(() => _isTimerRunning = false);

      Duration fetchedDuration = _elapsed; // fallback
      try {
        final id = _existingOrderId;
        if (id != null) {
          final res = await _repository.fetchOrderTimesheetCreateTime(id);
          AppLogger.info(
            'fetchOrderTimesheetCreateTime result: $res (elapsed was: $_elapsed)',
            tag: 'TIMER_DEBUG',
          );
          // Keep local elapsed when server returns null/zero unexpectedly.
          if (res != null) {
            fetchedDuration = res > Duration.zero ? res : _elapsed;
          }
        }
      } catch (e) {
        AppLogger.error('fetchOrderTimesheetCreateTime failed', tag: 'TIMER_DEBUG', error: e);
      }

      AppLogger.info('Opening dialog with duration: $fetchedDuration', tag: 'TIMER_DEBUG');
      await _showTimesheetLogDialog(overrideDuration: fetchedDuration);
    }

    Future<void> _onOrderActionPressed(String action) async {
      final id = _existingOrderId;
      if (id == null || _isClosed) return;
      final bool ok;
      if (action == 'complete') {
        ok = await _repository.actionCompleteOrder(id);
      } else if (action == 'cancel') {
        ok = await _repository.actionCancelOrder(id);
      } else {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (action == 'complete'
                    ? 'Order completed successfully'
                    : 'Order cancelled successfully')
                : (action == 'complete'
                    ? 'Failed to complete order'
                    : 'Failed to cancel order'),
          ),
        ),
      );
      if (!ok) return;
      await _loadExistingOrderData();
      if (Get.isRegistered<OrderController>()) {
        await Get.find<OrderController>().loadOrders();
      }
    }

    Future<void> _onStageSelected(int stageId) async {
      final orderId = _existingOrderId;
      if (orderId == null) return;
      if (_currentStageId == stageId) return;
      final previousStageId = _currentStageId;
      final previousStageName = _currentStageName;
      String selectedName = '—';
      for (final stage in _availableStages) {
        if (stage['id'] == stageId) {
          selectedName = stage['name']?.toString() ?? '—';
          break;
        }
      }
      setState(() {
        _currentStageId = stageId;
        _currentStageName = selectedName;
      });
      try {
        await _repository.updateOrder(orderId, <String, dynamic>{
          'stage_id': <dynamic>[stageId, selectedName],
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderStageUpdated} $selectedName')),
        );
        await _loadExistingOrderData();
        if (Get.isRegistered<OrderController>()) {
          await Get.find<OrderController>().loadOrders();
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _currentStageId = previousStageId;
          _currentStageName = previousStageName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.orderStageUpdateFailed)),
        );
      }
    }

    Future<void> _showTimesheetLogDialog({Duration? overrideDuration}) async {
      if (_isLogDialogOpen || !mounted) return;
      _isLogDialogOpen = true;
      final worked = overrideDuration ?? _elapsed;
      String activityText = '';
      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
            builder: (ctx) {
              return StatefulBuilder(
                builder: (ctx, setDialogState) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;

                  final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
                  final fieldColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100;
                  final labelColor = isDark ? Colors.white : Colors.black87;
                  final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
                  final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
                  final closeIconColor = isDark ? Colors.white70 : Colors.black87;
                  final timeColor = AppColors.primary;

                  return Dialog(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.orderTimesheetLogTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: labelColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close, size: 18, color: closeIconColor),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Time Spent label ─────────────────────────────────
                    Text(
                      '${AppStrings.orderTimesheetLogTimeSpent}:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: labelColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Time display box ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        OdooOrdersConfig.formatFloatTimeForUi(
                            worked.inMicroseconds / Duration.microsecondsPerHour),
                        style: TextStyle(
                          color: timeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Destination Location label ───────────────────────
                    Text(
                      AppStrings.orderTimesheetLogActivity,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: labelColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Activity text field ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        maxLines: 5,
                        onChanged: (v) => activityText = v,
                        style: TextStyle(color: labelColor),
                        decoration: InputDecoration(
                          hintText: AppStrings.orderTimesheetLogActivity,
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Action buttons ───────────────────────────────────
                    Row(
                      children: [
                        // Log Time
                        Expanded(
                          flex: 3,
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
                            onPressed: () async {
                              await _logTimesheet(activityText.trim(), worked);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child:  Text(
                              AppStrings.orderTimesheetLogButton,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Resume Timer
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _onTimerPauseResumePressed();
                              Navigator.of(ctx).pop();
                            },
                            child: Text(
                              AppStrings.orderTimesheetResumeTimer,
                              style: TextStyle(
                                color: labelColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Delete / Trash
                        // Delete / Trash
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              setState(() => _elapsed = Duration.zero);
                              Navigator.of(ctx).pop();
                            },
                            child: Icon(Icons.delete_outline, color: labelColor, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                  );
                }, // closes StatefulBuilder builder
              );   // closes StatefulBuilder
            },
        );
      } finally {
        _isLogDialogOpen = false;
      }
    }

    Future<void> _logTimesheet(String description, Duration worked) async {
      if (worked <= Duration.zero) return;
      final typeOpts = _optionsByField['timesheet_type_id'] ?? const <String>[];
      final empOpts = _optionsByField['employee_id'] ?? const <String>[];
      final typeLabel = typeOpts.isNotEmpty ? typeOpts.first : '-';
      final empLabel = empOpts.isNotEmpty ? empOpts.first : '-';
      final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final hoursExact = _hoursFromDurationForOdoo(worked);

      final empIdResolved = _coerceOdooId(_idForTimesheetDropdown('employee_id', empLabel)) ??
          await _repository.findHrEmployeeIdForSessionUser() ??
          _defaultEmployeeOdooId;
      final typeIdResolved = _coerceOdooId(_idForTimesheetDropdown('timesheet_type_id', typeLabel)) ??
          _defaultTimesheetTypeOdooId;

      String empDisplay = empLabel;
      if (empDisplay == '-' && empIdResolved != null) {
        final idx = _employeeIds.indexWhere((e) => _coerceOdooId(e) == empIdResolved);
        if (idx >= 0 && idx < empOpts.length) empDisplay = empOpts[idx];
      }
      String typeDisplay = typeLabel;
      if (typeDisplay == '-' && typeIdResolved != null) {
        final idx = _timesheetTypeIds.indexWhere((e) => _coerceOdooId(e) == typeIdResolved);
        if (idx >= 0 && idx < typeOpts.length) typeDisplay = typeOpts[idx];
      }

      final row = _TimesheetRow(
        odooId: null,
        date: day,
        timesheetType: typeDisplay,
        employee: empDisplay,
        name: description.isEmpty ? AppStrings.orderTimesheetWorkLog : description,
        unitAmountHours: hoursExact,
      );

      setState(() {
        _timesheetRows.insert(0, row);
        _elapsed = Duration.zero;
      });
      await _persistTimesheetRowsCache();

      final id = _existingOrderId;
      if (id == null) return;

      final vals = <String, dynamic>{
        OdooOrdersConfig.timesheetCreateOrderField: id,
        'name': row.name,
        'unit_amount': hoursExact,
        'date': day,
      };
      if (empIdResolved != null) vals['employee_id'] = empIdResolved;
      if (typeIdResolved != null) vals['timesheet_type_id'] = typeIdResolved;

      final created = await _repository.createTimesheetLine(vals);
      if (!mounted) return;
      if (created != null) {
        setState(() {
          if (_timesheetRows.isNotEmpty) {
            _timesheetRows[0] = row.copyWith(odooId: created);
          }
        });
        await _persistTimesheetRowsCache();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(AppStrings.orderTimesheetSaveOffline),
          ),
        );
      }
    }

    String _formatElapsed(Duration d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
    }

    void _putIfNotNull(Map<String, dynamic> values, String key, dynamic value) {
      if (value != null) values[key] = value;
    }

    void _putIfNotBlank(Map<String, dynamic> values, String key, String? value) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) {
        values[key] = v;
      }
    }

    Future<void> _loadPrimaryFieldOptions() async {
      setState(() {
        _isLoadingOptions = true;
        _loadError = '';
      });
      try {
        final data = await _repository.fetchCreateOrderFieldOptions(
          _primaryFields.map((f) => f.key).toList(),
        );

// Fetch timesheet types and employees separately from correct models
        final timesheetTypeOptions = await _repository.fetchOptionsFromModel(
          model: 'fsm.timesheet.type',
          labelField: 'name',
        );
        final employeeOptions = await _repository.fetchOptionsFromModel(
          model: 'hr.employee',
          labelField: 'name',
        );
        debugPrint('Timesheet type model test — trying fsm.timesheet.type');

        if (!mounted) return;
        setState(() {
          for (final f in _primaryFields) {
            final options = data[f.key] ?? const <OdooFieldOption>[];
            _optionsByField[f.key] = options.map((e) => e.label).toList();
            _primaryOptionIds[f.key] = options.map((e) => e.id).toList();
          }
          _timesheetTypeIds = timesheetTypeOptions.map((e) => e.id).toList();
          _optionsByField['timesheet_type_id'] = timesheetTypeOptions.map((e) => e.label).toList();
          _employeeIds = employeeOptions.map((e) => e.id).toList();
          _optionsByField['employee_id'] = employeeOptions.map((e) => e.label).toList();
          _isLoadingOptions = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoadingOptions = false;
          _loadError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.orderFieldsLoadFailed}$_loadError')),
        );
      }
    }

    bool _isCalendarDateTimeField(String key) {
      return key == 'request_early' ||
          key == 'request_late' ||
          key == 'scheduled_date_start';
    }

    Future<void> _pickDateTimeForField(String key) async {
      final now = DateTime.now();
      final initial = _tryParseDateTime(_selectedByField[key]) ?? now;
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null || !mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;

      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final formatted = _formatDateTime(dt);
      setState(() {
        final list = _optionsByField[key] ?? <String>[];
        if (!list.contains(formatted)) {
          _optionsByField[key] = <String>[formatted, ...list];
        }
        _selectedByField[key] = formatted;
      });
    }

    Future<void> _pickExecutionDateTime(String key) async {
      final now = DateTime.now();
      final ctrl = _controllerFor(key);
      final initial = _tryParseDateTime(ctrl.text) ?? now;
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null || !mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;

      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      setState(() {
        ctrl.text = _formatDateTime(dt);
      });
    }

    DateTime? _tryParseDateTime(String? value) {
      if (value == null || value.isEmpty) return null;
      try {
        final normalized = value.replaceAll('/', '-');
        final parts = normalized.split(' ');
        if (parts.length < 2) return DateTime.tryParse(normalized);
        final d = parts[0].split('-');
        final t = parts[1].split(':');
        if (d.length != 3 || t.length < 2) return DateTime.tryParse(normalized);
        final year = d[0].length == 4 ? int.parse(d[0]) : int.parse(d[2]);
        final month = int.parse(d[1]);
        final day = d[0].length == 4 ? int.parse(d[2]) : int.parse(d[0]);
        final hour = int.parse(t[0]);
        final minute = int.parse(t[1]);
        final second = t.length >= 3 ? (int.tryParse(t[2]) ?? 0) : 0;
        return DateTime(year, month, day, hour, minute, second);
      } catch (_) {
        return null;
      }
    }

    String _formatDateTime(DateTime dt) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    }

    String _formatDateTimeOrBlank(dynamic raw) {
      final dt = _parseOdooDateTime(raw);
      if (dt == null) return '';
      return _formatDateTime(dt);
    }
  }

  class _SelectFieldConfig {
    const _SelectFieldConfig({required this.key, required this.label});
    final String key;
    final String label;
  }

  class _WorkerRow {
    _WorkerRow({
      required this.name,
      required this.phone,
      required this.email,
      required this.schedule,
    });
    final String name;
    final String phone;
    final String email;
    final String schedule;
  }

  class _TimesheetRow {
    _TimesheetRow({
      this.odooId,
      required this.date,
      required this.timesheetType,
      required this.employee,
      required this.name,
      required double unitAmountHours,
    }) : _unitAmountHours = _coerceStoredHours(unitAmountHours);

    _TimesheetRow copyWithFields({
      String? timesheetType,
      String? employee,
      String? name,
      double? unitAmountHours,
    }) {
      return _TimesheetRow(
        odooId: odooId,
        date: date,
        timesheetType: timesheetType ?? this.timesheetType,
        employee: employee ?? this.employee,
        name: name ?? this.name,
        unitAmountHours: unitAmountHours ?? _unitAmountHours,
      );
    }

    final int? odooId;
    final String date;
    final String timesheetType;
    final String employee;
    final String name;

    /// Hours from Odoo `account.analytic.line` · `unit_amount` (float).
    final double _unitAmountHours;

    double get unitAmountHours => _unitAmountHours;

    /// Formatted for the Timesheet tab (matches Odoo float, no broken trimming).
    String get unitAmount => OdooOrdersConfig.formatUnitAmountHoursForUi(_unitAmountHours);

    static double _coerceStoredHours(double h) {
      if (h.isNaN || h.isInfinite) return 0.0;
      return h;
    }

    /// Reads `unit_amount` from RPC / Hive (also older cache keys if present).
    static double _hoursFromLineMap(Map<String, dynamic> m) {
      final raw = m['unit_amount'] ?? m['unitAmount'];
      return OdooOrdersConfig.parseUnitAmountHours(raw);
    }

    factory _TimesheetRow.fromOdooMap(Map<String, dynamic> m) {
      int? oid;
      final idv = m['id'];
      if (idv is int) {
        oid = idv;
      } else if (idv is num) {
        oid = idv.toInt();
      }
      final rawDate = m['date'];
      String dateLabel = '-';
      if (rawDate != null && rawDate != false) {
        final s = rawDate.toString();
        final dt = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
        dateLabel = dt != null ? DateFormat('yyyy-MM-dd').format(dt) : s;
      }
      return _TimesheetRow(
        odooId: oid,
        date: dateLabel,
        timesheetType: _m2oLabel(m['timesheet_type_id']),
        employee: _m2oLabel(m['employee_id']),
        name: (m['name'] ?? '').toString(),
        unitAmountHours: _hoursFromLineMap(m),
      );
    }

    static String _m2oLabel(dynamic v) {
      if (v == null || v == false) return '-';
      if (v is List && v.length >= 2) return v[1]?.toString() ?? '-';
      return v.toString();
    }

    _TimesheetRow copyWith({int? odooId, double? replaceUnitAmountHours}) {
      return _TimesheetRow(
        odooId: odooId ?? this.odooId,
        date: date,
        timesheetType: timesheetType,
        employee: employee,
        name: name,
        unitAmountHours: replaceUnitAmountHours ?? _unitAmountHours,
      );
    }

    Map<String, dynamic> toOdooCacheLite() {
      return <String, dynamic>{
        'id': odooId,
        'date': date,
        'name': name,
        'unit_amount': _unitAmountHours,
        'employee_id': employee == '-' ? false : <dynamic>[0, employee],
        'timesheet_type_id': timesheetType == '-' ? false : <dynamic>[0, timesheetType],
      };
    }
  }

  class _BadgedIcon extends StatelessWidget {
    const _BadgedIcon({
      required this.child,
      required this.count,
    });

    final Widget child;
    final int count;

    @override
    Widget build(BuildContext context) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,

          if (count > 0)
            Positioned(
              right: -6,  // ⬅️ move outside properly
              top: -6,    // ⬅️ move to top corner
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 9, // slightly smaller for better fit
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }



  // ─── Vehicle Stock Row ───────────────────────────────────────────────────────
  class _VehicleStockRow {
    _VehicleStockRow({
      required this.productId,
      required this.productName,
      required this.availableQty,
      required this.quantity,
      required this.lotId,
      required this.lotName,
    });

    final int productId;
    final String productName;
    final double availableQty;
    double quantity;
    final int? lotId;
    final String lotName;

    Map<String, dynamic> toPayload() => <String, dynamic>{
      'product_id': productId,
      'qty_available': availableQty,
      'quantity': quantity,
      if (lotId != null) 'lot_id': lotId,
    };
  }

  class _VehicleProductOption {
    const _VehicleProductOption({
      required this.id,
      required this.name,
      required this.availableQty,
      required this.lotId,
      required this.lotName,
    });

    final int id;
    final String name;
    final double availableQty;
    final int? lotId;
    final String lotName;
  }

  class _OrderStockView extends StatelessWidget {
    const _OrderStockView({required this.items});

    final List<VehicleStockItem> items;

    String _fmt(double v) {
      if (v == v.roundToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(2);
    }

    @override
    Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const tableWidth = 996.0; // row content + inner paddings
      return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFCFCFC),
        appBar: AppBar(
        title: Text(
          AppStrings.orderStockTitle,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.white,
          ),
        ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: items.isEmpty
          ? Center(
              child: Text(
                AppStrings.orderStockNoData,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFE7E7E7)),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Container(
                          color: isDark ? AppColors.darkSurface2 : const Color(0xFFEDEDED),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 180,
                                  child: Text(AppStrings.orderStockColLocation,
                                      style:
                                          TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ))),
                              SizedBox(width: 12),
                              SizedBox(
                                  width: 250,
                                  child: Text(AppStrings.orderStockColProduct,
                                      style:
                                          TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ))),
                              SizedBox(width: 12),
                              SizedBox(
                                  width: 160,
                                  child: Text(AppStrings.orderStockColLot,
                                      style:
                                          TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ))),
                              SizedBox(width: 12),
                              SizedBox(
                                  width: 130,
                                  child: Text(AppStrings.orderStockColOnHand,
                                      style:
                                          TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ))),
                              SizedBox(width: 12),
                              SizedBox(
                                  width: 180,
                                  child: Text(AppStrings.orderStockColReserved,
                                      style:
                                          TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ))),
                            ],
                          ),
                        );
                      }

                      final item = items[i - 1];
                      return Container(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF8F8F8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 180,
                              child: Text(
                                item.location,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 250,
                              child: Text(
                                item.product,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 160,
                              child: Text(
                                item.lotSerial,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 130,
                              child: Text(
                                _fmt(item.onHandQty),
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 180,
                              child: Text(
                                '${_fmt(item.reservedQty)} ${item.unit}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
      );
    }
  }
