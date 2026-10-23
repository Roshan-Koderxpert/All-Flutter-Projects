import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../routes/app_routes.dart';

enum _ProductScreenMode { fsmOrder, carInventory }

class OrderProductsView extends StatefulWidget {
  const OrderProductsView({super.key});

  @override
  State<OrderProductsView> createState() => _OrderProductsViewState();
}

class _OrderProductsViewState extends State<OrderProductsView> {
  final OrderRepository _repository = Get.find<OrderRepository>();

  late final int _partnerId;
  late final int? _fsmOrderId;
  late final _ProductScreenMode _mode;


  List<ProductItem> _products = [];
  List<ProductItem> _carInventoryProducts = [];  bool _isLoading = true;
  String _error = '';
  // Tracks which products user agreed to take from warehouse
  final Map<int, bool> _useWarehouseStockFor = {};

  // Cart: productId → quantity
  final Map<int, int> _cart = {};


  final Set<int> _vehicleStockProductIds = {};

  int? _saleOrderId;
  Map<String, dynamic>? _saleOrderData;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _partnerId  = (args?['partnerId']  as int?) ?? 0;
    _fsmOrderId = args?['fsmOrderId']  as int?;
    _mode = (args?['mode'] as String?) == 'carInventory'
        ? _ProductScreenMode.carInventory
        : _ProductScreenMode.fsmOrder;

    _initAll();
  }

  Future<void> _initAll() async {
    // Load products first, then sync cart state from existing sale order
    await _fetchData();
    await _loadExistingSaleOrder();
  }

  Future<void> _loadExistingSaleOrder() async {
    if (_fsmOrderId == null) return;
    final existing = await _repository.fetchOrCreateSaleOrderForFsm(
      fsmOrderId: _fsmOrderId!,
    );
    if (existing != null && mounted) {
      debugPrint('Pre-existing sale order found: ${existing['id']}');
      setState(() {
        _saleOrderData = existing;
        _saleOrderId = existing['id'] as int?;

        // Pre-populate cart from existing sale order lines
        final lines = (existing['lines'] as List?) ?? [];
        for (final line in lines) {
          if (line is! Map) continue;
          final m = Map<String, dynamic>.from(line);
          final pid = m['product_id'];
          int? productId;
          if (pid is List && pid.isNotEmpty) {
            productId = pid.first is int ? pid.first as int : null;
          }
          final qty = (m['product_uom_qty'] as num?)?.toInt() ?? 0;
          if (productId != null && qty > 0) {
            _cart[productId] = qty;
          }
        }
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      if (_mode == _ProductScreenMode.carInventory) {
        await _fetchCarInventory();
      } else {
        await _fetchFsmProducts();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetchFsmProducts() async {
    final items = await _repository.fetchProductsForPartner(partnerId: _partnerId);
    if (_fsmOrderId != null) {
      try {
        final defaults = await _repository.fetchVehicleStockWizardDefaults(
            fsmOrderId: _fsmOrderId!);
        final vehicleId = _coerceInt(defaults['vehicle_id']);
        if (vehicleId != null) {
          final quants = await _repository.fetchVehicleStockProducts(vehicleId: vehicleId);
          _vehicleStockProductIds.clear();
          for (final q in quants) {
            final pid = _m2oId(q['product_id']);
            if (pid != null) _vehicleStockProductIds.add(pid);
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _products = items; _isLoading = false; });
  }

  Future<void> _fetchCarInventory() async {
    if (_fsmOrderId == null) {
      setState(() { _carInventoryProducts = []; _isLoading = false; });
      return;
    }
    final items = await _repository.fetchVehicleStockProducts_ForCarInventory(
        fsmOrderId: _fsmOrderId!);
    if (!mounted) return;
    setState(() { _carInventoryProducts = items; _isLoading = false; });
  }


  Future<void> _addToCart(ProductItem product) async {
    if (_fsmOrderId == null) return;

    final currentQty = _cart[product.id] ?? 0;
    final newQty = (currentQty + 1).toDouble();

    debugPrint('=== ADD TO CART (FSM tab) ===');
    debugPrint('Product: ${product.name} (id: ${product.id}) newQty: $newQty');

    // Step 1: Check vehicle stock availability (mirrors JS _checkVehicleStockAndConfirm)
    final canProceed = await _checkVehicleStockAndConfirm(product, newQty);
    if (!canProceed) {
      debugPrint('User cancelled — not proceeding');
      return;
    }

    debugPrint('Can proceed: $canProceed');

    // Step 2: Update cart UI
    setState(() {
      _cart[product.id] = currentQty + 1;
      _products.sort((a, b) {
        final aInCart = _cart.containsKey(a.id) ? 0 : 1;
        final bInCart = _cart.containsKey(b.id) ? 0 : 1;
        return aInCart.compareTo(bInCart);
      });
    });

    // Step 3: Call Odoo to set quantity (uses warehouse flag from step 1)
    final result = await _repository.setFsmProductQuantity(
      fsmOrderId: _fsmOrderId!,
      productId: product.id,
      quantity: newQty,
      useWarehouseStock: _useWarehouseStockFor[product.id] ?? false,
    );

    if (result != null && mounted) {
      setState(() {
        _saleOrderData = result;
        _saleOrderId = result['id'] as int?;
      });
    }
  }

  /// Mirrors JS _checkVehicleStockAndConfirm: checks availability,
  /// shows dialog if insufficient, returns true if user wants to proceed.
  Future<bool> _checkVehicleStockAndConfirm(ProductItem product, double newQty) async {
    if (_fsmOrderId == null) return true;

    final connectivity = Get.find<ConnectivityService>();
    final network = Get.find<NetworkService>();
    final sid = network.sessionId;
    final base = network.baseUrl;
    final canReachOdoo = connectivity.hasConnection &&
        sid != null && sid.isNotEmpty &&
        base != null && base.isNotEmpty;

    if (!canReachOdoo) {
      // Offline: use cached vehicle stock product ids
      // If product IS in vehicle stock → no warning, proceed directly
      if (_vehicleStockProductIds.contains(product.id)) {
        _useWarehouseStockFor[product.id] = false;
        debugPrint('Availability check: OFFLINE — product in vehicle stock, proceed');
        return true;
      }
      // Product NOT in vehicle stock → show warning dialog
      debugPrint('Availability check: OFFLINE — product NOT in vehicle stock, show warning');
      final proceed = await _showVehicleStockWarningDialog(
        product: product,
        requiredQty: newQty.toInt(),
        availableInVehicle: 0,
        warehouseQty: 0,
        missingQty: newQty,
        warehouseAvailable: false,
      );
      if (proceed) {
        _useWarehouseStockFor[product.id] = true;
      }
      return proceed;
    }

    // Online: call Odoo as before
    final avail = await _repository.checkVehicleStockAvailability(
      fsmOrderId: _fsmOrderId!,
      productId: product.id,
      quantity: newQty,
    );

    debugPrint('Availability check: $avail');

    if (avail == null || avail['insufficient'] != true) {
      _useWarehouseStockFor[product.id] = false;
      return true;
    }

    final proceed = await _showVehicleStockWarningDialog(
      product: product,
      requiredQty: newQty.toInt(),
      availableInVehicle: (avail['available_qty'] as num?)?.toDouble() ?? 0,
      warehouseQty: (avail['warehouse_qty'] as num?)?.toDouble() ?? 0,
      missingQty: (avail['missing_qty'] as num?)?.toDouble() ?? 0,
      warehouseAvailable: avail['warehouse_available'] == true,
    );

    if (proceed) {
      _useWarehouseStockFor[product.id] = true;
    }

    return proceed;
  }


// FSM Order tab — checks vehicle stock, shows warning if not available

// Car Inventory tab — products are already in vehicle, no warning needed
  Future<void> _addToCartFromCarInventory(ProductItem product) async {
    if (_fsmOrderId == null) return;

    final currentQty = _cart[product.id] ?? 0;
    final newQty = (currentQty + 1).toDouble();

    debugPrint('=== ADD FROM CAR INVENTORY ===');
    debugPrint('Product: ${product.name} (id: ${product.id}) newQty: $newQty');
    debugPrint('  current _cart before add: $_cart, mode=$_mode, fsmOrderId=$_fsmOrderId');

    setState(() {
      _cart[product.id] = currentQty + 1;
    });

    // Car inventory products are in vehicle → useWarehouseStock = false
    await _repository.setFsmProductQuantity(
      fsmOrderId: _fsmOrderId!,
      productId: product.id,
      quantity: newQty,
      useWarehouseStock: false,
    );
  }

  Future<void> _removeFromCart(int productId) async {
    if (_fsmOrderId == null) return;

    final current = _cart[productId] ?? 0;
    if (current <= 0) return;

    final newQty = (current - 1).toDouble();

    debugPrint('=== REMOVE FROM CART ===');
    debugPrint('productId: $productId  current: $current  newQty: $newQty');

    // Update UI immediately
    setState(() {
      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty.toInt();
      }
    });

    // Sync to Odoo — same endpoint, pass 0 to remove or new qty to update
    final result = await _repository.setFsmProductQuantity(
      fsmOrderId: _fsmOrderId!,
      productId: productId,
      quantity: newQty,
      useWarehouseStock: _useWarehouseStockFor[productId] ?? false,
    );

    if (result != null && mounted) {
      setState(() {
        _saleOrderData = result;
        _saleOrderId = result['id'] as int?;
      });
    }
  }


  Future<void> _syncCartToSaleOrder() async {
    debugPrint('=== SYNC CART TO SALE ORDER (FSM FLOW) ===');
    debugPrint('fsmOrderId: $_fsmOrderId, partnerId: $_partnerId');
    debugPrint('cart: $_cart');

    if (_fsmOrderId == null || _partnerId <= 0) {
      debugPrint('SKIPPED — fsmOrderId or partnerId missing');
      return;
    }

    try {
      // For each product in cart, call setFsmProductQuantity
      // This uses Odoo's native FSM flow (product.set_fsm_quantity + _sync_fsm_products_to_sale_order)
      Map<String, dynamic>? lastResult;

      for (final entry in _cart.entries) {
        final productId = entry.key;
        final qty = entry.value.toDouble();

        debugPrint('  Setting product $productId qty=$qty');
        lastResult = await _repository.setFsmProductQuantity(
          fsmOrderId: _fsmOrderId!,
          productId: productId,
          quantity: qty,
        );
      }

      if (lastResult == null) {
        // Fallback: try to fetch sale order directly
        lastResult = await _repository.fetchOrCreateSaleOrderForFsm(
          fsmOrderId: _fsmOrderId!,
        );
      }

      if (lastResult != null && mounted) {
        debugPrint('Sale order synced: ${lastResult['id']} — ${lastResult['name']}');
        debugPrint('Lines: ${lastResult['lines']}');
        setState(() {
          _saleOrderData = lastResult;
          _saleOrderId = lastResult?['id'] as int?;
        });
      } else {
        debugPrint('Sale order sync returned NULL');
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale order sync failed: $e')),
        );
      }
    }
  }

  void _openSaleOrderScreen() {
    debugPrint('=== OPEN SALE ORDER ===');
    debugPrint('saleOrderData: ${_saleOrderData?['id']} name: ${_saleOrderData?['name']}');
    debugPrint('lines count: ${(_saleOrderData?['lines'] as List?)?.length}');

    if (_saleOrderData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sale order created yet. Please add products first.')),
      );
      return;
    }

    // Pass saleOrderData directly — do NOT rely on FSM order lookup
    // because the newly created sale order may not be linked to FSM order yet
    Get.toNamed(
      AppRoutes.saleOrder,
      arguments: <String, dynamic>{
        'saleOrderData': _saleOrderData,   // ← pass full data directly
        'fsmOrderId': _fsmOrderId,
        'partnerId': _partnerId,
      },
    );
  }
  int get _totalCartCount => _cart.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
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
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (!_isLoading && _error.isEmpty)
                Container(
                  color: isDark ? AppColors.darkSurface : AppColors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _mode == _ProductScreenMode.carInventory
                          ? '${_carInventoryProducts.length} product${_carInventoryProducts.length == 1 ? '' : 's'}'
                          : '${_products.length} product${_products.length == 1 ? '' : 's'}',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                )
                    : _error.isNotEmpty
                    ? _buildError()
                    : _mode == _ProductScreenMode.carInventory
                    ? _buildCarInventoryList()
                    : _products.isEmpty
                    ? _buildEmpty()
                    : _buildProductList(),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
        (_mode == _ProductScreenMode.fsmOrder &&
            (_totalCartCount > 0 || _saleOrderData != null))
            ? _buildCartBar()
            : null,
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: back + right icons
          Row(
            children: [
              GestureDetector(
                onTap: _handleBackPressed,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: tab chips — sits below, no overflow
          Row(
            children: [
              GestureDetector(
                onTap: _handleBackPressed,
                child: _HeaderTab(
                    label: 'FSM Order',
                    selected: _mode == _ProductScreenMode.fsmOrder),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  if (_mode != _ProductScreenMode.carInventory) {
                    // Await result — Car Inventory tab returns its _cart map
                    final result = await Get.to<Map<String, dynamic>?>(
                          () => const OrderProductsView(),
                      arguments: <String, dynamic>{
                        'partnerId': _partnerId,
                        'fsmOrderId': _fsmOrderId,
                        'mode': 'carInventory',
                      },
                    );
                    debugPrint('  returned from Car Inventory (Get.to is NOT awaited — cart merge wont happen here)');

                    // Merge Car Inventory cart into FSM tab cart
                    if (result != null && mounted) {
                      final carCart = result['cart'] as Map<int, int>?;
                      final carSaleOrder = result['saleOrderData'] as Map<String, dynamic>?;
                      if (carCart != null && carCart.isNotEmpty) {
                        setState(() {
                          for (final e in carCart.entries) {
                            _cart[e.key] = (_cart[e.key] ?? 0) + e.value;
                          }
                        });
                      }
                      if (carSaleOrder != null) {
                        setState(() {
                          _saleOrderData = carSaleOrder;
                          _saleOrderId = carSaleOrder['id'] as int?;
                        });
                      }
                    }
                  }
                },
                child: _HeaderTab(
                    label: 'Car Inventory',
                    selected: _mode == _ProductScreenMode.carInventory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Product list ──────────────────────────────────────────────────────────
  Widget _buildProductList() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final p = _products[i];
          return _ProductCard(
            product: p,
            cartQty: _cart[p.id] ?? 0,
            onAdd: () => _addToCart(p),
            onRemove: () => _removeFromCart(p.id),
          );
        },
      ),
    );
  }

  Widget _buildCarInventoryList() {
    if (_carInventoryProducts.isEmpty) {
      return Center(
        child: Text(
          'No stock products found for this vehicle.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        itemCount: _carInventoryProducts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final p = _carInventoryProducts[i];
          return _ProductCard(
            product: p,
            cartQty: _cart[p.id] ?? 0,
            onAdd: () => _addToCartFromCarInventory(p),
            onRemove: () => _removeFromCart(p.id),
          );
        },
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
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No products found for this partner.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  // ── Cart bottom bar ───────────────────────────────────────────────────────
  Widget _buildCartBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = _totalCartCount;
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count product${count == 1 ? '' : 's'} selected',
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600),
                ),
                if (_saleOrderData != null)
                  Text(
                    'Sale Order: ${_saleOrderData!['name'] ?? ''}',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (_cart.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _cart.clear()),
              child: const Text('Clear',
                  style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  Future<bool> _showVehicleStockWarningDialog({
    required ProductItem product,
    required int requiredQty,
    required double availableInVehicle,
    double warehouseQty = 0,
    double missingQty = 0,
    bool warehouseAvailable = false,
  }) async {
    // Fetch available qty in warehouse (internal locations)
    double warehouseQty = 0.0;
    try {
      warehouseQty = await _repository.fetchWarehouseAvailableQty(
          productId: product.id);
    } catch (_) {}

    final fromVehicle = availableInVehicle.toInt();
    final fromWarehouse = (requiredQty - availableInVehicle).ceil();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
        builder: (ctx) {
          final isDark = Theme
              .of(ctx)
              .brightness == Brightness.dark;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 40),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Vehicle Stock Warning',
                            style: AppTextStyles.h2.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(false),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _dialogInfoBox(child: Text(
                    'Stock is not fully available in vehicle. Still you need to go further?',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ), isDark: isDark),

                  const SizedBox(height: 10),
                  _dialogInfoBox(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogDetailRow('Product:', product.name, isDark: isDark),
                      _dialogDetailRow('Available in vehicle:', '$availableInVehicle', isDark: isDark),
                      _dialogDetailRow('Required:', '$requiredQty', isDark: isDark),
                      _dialogDetailRow('Available In Warehouse:', '$warehouseQty', isDark: isDark),
                    ],
                  ), isDark: isDark),
                  const SizedBox(height: 10),
                  _dialogInfoBox(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('If you proceed:',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      if (fromVehicle > 0)
                        _bulletText('$fromVehicle qty will be deducted from vehicle stock', isDark: isDark),
                      _bulletText('$fromWarehouse qty will be deducted from warehouse stock', isDark: isDark),
                    ],

                  ),isDark: isDark),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Yes',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD)),                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('No',
                              style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
    );
    return result ?? false;
  }

  Widget _dialogInfoBox({required Widget child, bool isDark = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: child,
    );
  }

  Widget _dialogDetailRow(String label, String value, {bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text('$label $value',
          style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textPrimary)),
    );
  }

  Widget _bulletText(String text, {bool isDark = false}) {
    final color = isDark ? AppColors.darkTextSecondary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: AppTextStyles.bodyMedium.copyWith(color: color)),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: color)),
          ),
        ],
      ),
    );
  }


  Future<void> _showSaleOrderConfirmation(VehicleStockItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Sale Order',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Do you want to create a sale order for:'),
            const SizedBox(height: 10),
            _dialogInfoBox(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogDetailRow('Product:', item.product),
                _dialogDetailRow('Location:', item.location),
                _dialogDetailRow('On Hand:', '${item.onHandQty} ${item.unit}'),
              ],
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sale order created successfully'),
        backgroundColor: Colors.green,
      ));
    }
  }


  Future<void> _showCarInventorySaleOrderConfirmation(ProductItem product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Sale Order',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Do you want to create a sale order for:'),
            const SizedBox(height: 10),
            _dialogInfoBox(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogDetailRow('Product:', product.name),
                if (product.internalRef.isNotEmpty)
                  _dialogDetailRow('Ref:', '[${product.internalRef}]'),
                _dialogDetailRow('Unit Price:',
                    '\$ ${product.price.toStringAsFixed(2)}'),
                _dialogDetailRow('On Hand:',
                    '${product.onHandQty.toStringAsFixed(2)} Units'),
              ],
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final result = await _repository.createSaleOrder(
        partnerId: _partnerId,
        fsmOrderId: _fsmOrderId ?? 0,
        lines: [<String, dynamic>{
          'product_id': product.id,
          'qty': 1.0,
          'price_unit': product.price,
        }],
      );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _saleOrderData = result;
          _saleOrderId = result['id'] as int?;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sale order ${result['name']} created!'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to create sale order.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  int? _coerceInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  int? _m2oId(dynamic v) {
    if (v is List && v.isNotEmpty) {
      final f = v.first;
      if (f is int) return f;
      if (f is num) return f.toInt();
      return int.tryParse(f.toString());
    }
    return _coerceInt(v);
  }

  bool _isSyncing = false;

  Future<void> _handleBackPressed() async {
    debugPrint('=== BACK PRESSED ===');
    debugPrint('  mode=$_mode, fsmOrderId=$_fsmOrderId');
    debugPrint('  _cart=$_cart');
    debugPrint('  _saleOrderData=${_saleOrderData?['id']} name=${_saleOrderData?['name']} queued=${_saleOrderData?['queued_offline']}');

    // Car Inventory tab — just return cart so FSM tab can merge it
    if (_mode == _ProductScreenMode.carInventory) {
      if (mounted) {
        Get.back(result: <String, dynamic>{
          'cart': Map<int, int>.from(_cart),
          'saleOrderData': _saleOrderData,
        });
      }
      return;
    }

    // FSM tab
    if (_fsmOrderId != null) {
      final connectivity = Get.find<ConnectivityService>();
      final network = Get.find<NetworkService>();
      final sid = network.sessionId;
      final base = network.baseUrl;
      final canReachOdoo = connectivity.hasConnection &&
          sid != null && sid.isNotEmpty &&
          base != null && base.isNotEmpty;

      debugPrint('  canReachOdoo=$canReachOdoo hasConnection=${connectivity.hasConnection} sid=$sid base=$base');

      if (canReachOdoo) {
        debugPrint('  calling fetchOrCreateSaleOrderForFsm ONLINE...');
        final so = await _repository.fetchOrCreateSaleOrderForFsm(
          fsmOrderId: _fsmOrderId!,
        );
        debugPrint('  result: id=${so?['id']} name=${so?['name']} isNull=${so == null}');

        if (mounted && so != null) {
          setState(() {
            _saleOrderData = so;
            _saleOrderId = so['id'] as int?;
          });
        } else if (mounted && so == null && _cart.isNotEmpty) {
          debugPrint('  online but no sale order found — building local from cart');
          _buildLocalSaleOrderFromCart();
        }
      } else {
        debugPrint('  OFFLINE branch — cart.isNotEmpty=${_cart.isNotEmpty}');
        if (_cart.isNotEmpty &&
            (_saleOrderData == null || _saleOrderData!['queued_offline'] == true)) {
          _buildLocalSaleOrderFromCart();
        }
      }
    }

    debugPrint('  final _saleOrderData: id=${_saleOrderData?['id']} name=${_saleOrderData?['name']} queued=${_saleOrderData?['queued_offline']} isNull=${_saleOrderData == null}');
    debugPrint('  lines count: ${(_saleOrderData?['lines'] as List?)?.length}');

    if (mounted) Get.back(result: _saleOrderData);
  }

  void _buildLocalSaleOrderFromCart() {
    final localLines = _cart.entries.map((e) {
      final product = _products.firstWhereOrNull((p) => p.id == e.key);
      return <String, dynamic>{
        'product_id': [e.key, product?.name ?? 'Product #${e.key}'],
        'product_uom_qty': e.value.toDouble(),
        'price_unit': product?.price ?? 0.0,
        'price_subtotal': (product?.price ?? 0.0) * e.value,
      };
    }).toList();

    final totalAmount = _cart.entries.fold(0.0, (sum, e) {
      final product = _products.firstWhereOrNull((p) => p.id == e.key);
      return sum + ((product?.price ?? 0.0) * e.value);
    });

    debugPrint('  _buildLocalSaleOrderFromCart: cart=$_cart lines=${localLines.length} total=$totalAmount');

    final localSaleOrder = <String, dynamic>{
      'id': null,
      'name': 'Pending Sale Order (Offline)',
      'state': 'draft',
      'queued_offline': true,
      'partner_id': [_partnerId, ''],
      'amount_total': totalAmount,
      'amount_untaxed': totalAmount,
      'lines': localLines,
    };

    // Save to Hive so flash→Sale Order also works offline
    if (_fsmOrderId != null) {
      _repository.saveOfflineSaleOrderForFsm(
        fsmOrderId: _fsmOrderId!,
        localSaleOrder: localSaleOrder,
      );
    }

    // Save to Hive so flash→Sale Order also works offline
    if (_fsmOrderId != null) {
      _repository.saveOfflineSaleOrderForFsm(
        fsmOrderId: _fsmOrderId!,
        localSaleOrder: localSaleOrder,
      );
    }

    if (mounted) {
      setState(() {
        _saleOrderData = localSaleOrder;
        _saleOrderId = null;
      });
    }
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Product Card
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.cartQty,
    required this.onAdd,
    required this.onRemove,
  });

  final ProductItem product;
  final int cartQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: product info ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Star + Product name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border_rounded,
                        size: 24, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        product.name,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Internal reference
                if (product.internalRef.isNotEmpty) ...[
                  Text(
                    '[${product.internalRef}]',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                ],

                // Unit price
                Text(
                  'Unit Price: \$ ${product.price.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textPrimary),
                ),
                const SizedBox(height: 2),

                // On hand
                Text(
                  'On hand: ${product.onHandQty.toStringAsFixed(2)} Units',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textPrimary),
                ),

                // Attribute tags
                if (product.attributes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: product.attributes
                        .asMap()
                        .entries
                        .map((e) => _AttributeTag(
                      label: e.value,
                      colorIndex: e.key,
                    ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right: image + Add button ──────────────────────────────────
          Column(
            children: [
              // Product image
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFEAEAEA)),
                ),
                clipBehavior: Clip.antiAlias,
                child: product.imageBase64.isNotEmpty
                    ? Image.memory(
                  base64Decode(product.imageBase64),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      _placeholder(),
                )
                    : _placeholder(),
              ),
              const SizedBox(height: 8),

              // Add / stepper
              cartQty == 0
                  ? _AddButton(onTap: onAdd)
                  : _StepperButton(
                qty: cartQty,
                onAdd: onAdd,
                onRemove: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.inventory_2_outlined,
          size: 36, color: Color(0xFFCCCCCC)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Button
// ─────────────────────────────────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD)),
        ),
        alignment: Alignment.center,
        child: Text(
          'Add',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }}

// ─────────────────────────────────────────────────────────────────────────────
// Stepper Button (qty > 0)
// ─────────────────────────────────────────────────────────────────────────────
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onRemove,
            child: const SizedBox(
              width: 32,
              height: 36,
              child:
              Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: const SizedBox(
              width: 32,
              height: 36,
              child: Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attribute Tag
// ─────────────────────────────────────────────────────────────────────────────
class _AttributeTag extends StatelessWidget {
  const _AttributeTag(
      {required this.label, required this.colorIndex});
  final String label;
  final int colorIndex;

  static const List<Color> _tagColors = [
    Color(0xFFFFC107), // amber
    Color(0xFF2196F3), // blue
    Color(0xFF4CAF50), // green
    Color(0xFF9C27B0), // purple
    Color(0xFFFF5722), // deep orange
  ];

  @override
  Widget build(BuildContext context) {
    final bg = _tagColors[colorIndex % _tagColors.length];
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Tab chip
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderTab extends StatelessWidget {
  const _HeaderTab({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? (isDark ? AppColors.darkSurface3 : const Color(0xFFE8E8E8))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? (isDark ? AppColors.darkBorder : const Color(0xFFCCCCCC))
              : (isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0)),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: selected
              ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
              : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        ),
      ),
    );
  }}

// ─────────────────────────────────────────────────────────────────────────────
// Header icon button
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0)),
      ),
      child: Icon(icon, size: 18,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
    );
  }
}


