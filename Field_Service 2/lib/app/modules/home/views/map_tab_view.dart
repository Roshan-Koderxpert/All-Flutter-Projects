import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/fsm_location_dialog_model.dart';
import '../../../data/models/order_model.dart';
import '../../../routes/app_routes.dart';
import '../controllers/order_controller.dart';

class MapTabView extends GetView<OrderController> {
  const MapTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? AppColors.darkBackground : AppColors.white,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.loadOrders,
          child: Stack(
            children: [
              // Transparent scrollable — exists only to give RefreshIndicator
              // something to pull against from anywhere on screen
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox.shrink()],
              ),
              // Actual content on top — original layout unchanged
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: _buildMapViewSection(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  AppStrings.navMap,
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
           
          ],
          ),
        ),

      ],
    );
  }

  Widget _buildMapViewSection(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final items = controller.mapOrders;
      final selectedId = controller.selectedMapOrderId.value;
      final routeIds = controller.routeOrderIds;
      final isRouting = controller.isRoutingMode.value;
      final isFullscreen = controller.isMapFullscreen.value;

      final selected = items.where((e) => e.order.id == selectedId && e.hasCoordinates).cast<OrderMapItem?>().firstOrNull;
      final fallback = items.where((e) => e.hasCoordinates).cast<OrderMapItem?>().firstOrNull;
      final rawLat = selected?.latitude ?? fallback?.latitude ?? 20.5937;
      final rawLng = selected?.longitude ?? fallback?.longitude ?? 78.9629;
      final centerLat = rawLat.isFinite ? rawLat : 20.5937;
      final centerLng = rawLng.isFinite ? rawLng : 78.9629;
      final routePoints = controller.routePolylinePoints.toList();
      final isOffline = Get.isRegistered<ConnectivityService>() &&
          !Get.find<ConnectivityService>().hasConnection;
      final routeIsEstimate = controller.routePolylineIsEstimate.value;

      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED)),
        ),
        child: Column(
          children: [
            // ── MAP (takes all available space above bottom panel) ──
            Expanded(
              child: ClipRRect(
                borderRadius: isFullscreen
                    ? BorderRadius.circular(16)
                    : const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    // ── Flutter Map ──
                    controller.isMapLoading.value
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : FlutterMap(
                      key: ValueKey<String>('map-$selectedId-${routeIds.length}-$isFullscreen'),
                      options: MapOptions(
                        initialCenter: LatLng(centerLat, centerLng),
                        initialZoom: 13.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.fieldservice.app',
                        ),
                        if (routePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                color: AppColors.primary,
                                strokeWidth: 5,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: items.where((e) => e.hasCoordinates).map((item) {
                            final isSelected = item.order.id == selectedId;
                            final routeIdx = routeIds.indexOf(item.order.id);
                            final inRoute = routeIdx != -1;
                            return Marker(
                              point: LatLng(item.latitude!, item.longitude!),
                              width: 48,
                              height: 52,
                              child: GestureDetector(
                                onTap: () => controller.focusMapOrder(item.order.id),
                                child: _buildMarker(
                                  isSelected: isSelected,
                                  routeIndex: inRoute ? routeIdx : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // ── Offline / estimate hint ──
                    if (isOffline || routeIsEstimate)
                      Positioned(
                        top: 10,
                        left: 12,
                        right: 12,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isOffline
                                  ? 'Offline — cached pins & route; map tiles need network'
                                  : 'Estimated route (straight line / cached)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Calculating badge (top center) ──
                    if (controller.isFetchingRoute.value)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Text('Calculating route…', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ── Route info pill (bottom center, above controls) ──
                    if (routePoints.length >= 2 && !controller.isFetchingRoute.value)
                      Positioned(
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Obx(() {
                            final stats = controller.routeStats;
                            final km = stats.totalKm;
                            final mins = stats.totalMinutes;
                            final timeLabel = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 12, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(timeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  Container(width: 1, height: 13, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.grey.shade300),
                                  const Icon(Icons.straighten_rounded, size: 15, color: Colors.black87),
                                  const SizedBox(width: 4),
                                  Text('${km.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                                  Container(width: 1, height: 13, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.grey.shade300),
                                  const Icon(Icons.location_on_rounded, size: 15, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text('${controller.routeItems.length} stops', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),

                    // ── Fullscreen toggle (bottom-left) ──
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: controller.toggleMapFullscreen,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Icon(
                            isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            size: 22,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM PANEL (hidden in fullscreen) ──
            if (!isFullscreen) ...[

              // ── Selected order card ──
              _buildSelectedOrderCard(isDark: isDark, items: items),

              // ── Tab bar ──
              _buildBottomTabBar(isDark: isDark, isRouting: isRouting),

              // ── Orders / Route panel ──
              SizedBox(
                height: 260,
                child: isRouting
                    ? _buildRoutingPanel(context, isDark: isDark)
                    : _buildOrderListPanel(context, isDark: isDark, items: items, selectedId: selectedId),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ── Marker widget ────────────────────────────────────────────────
  Widget _buildMarker({required bool isSelected, int? routeIndex}) {
    final inRoute = routeIndex != null;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.location_on,
          size: isSelected ? 42 : 34,
          color: inRoute
              ? AppColors.primary
              : isSelected
              ? Colors.deepOrange
              : Colors.red,
        ),
        if (inRoute)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${routeIndex + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

// ── Tab bar ──────────────────────────────────────────────────────
  Widget _buildBottomTabBar({required bool isDark, required bool isRouting}) {
    return Obx(() {
      final routeCount = controller.routeOrderIds.length;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
          border: Border.symmetric(
            horizontal: BorderSide(
              color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
            ),
          ),
        ),
        child: Row(
          children: [
            _tabChip(
              label: AppStrings.mapOrders,
              active: !isRouting,
              isDark: isDark,
              onTap: () {
                debugPrint('[ROUTE] tab→Orders, routeIds=${controller.routeOrderIds.length}');
                if (isRouting) controller.toggleRoutingMode();
              },
            ),
            const SizedBox(width: 8),
            _tabChip(
              label: routeCount > 0 ? 'Route ($routeCount)' : 'Route',
              active: isRouting,
              isDark: isDark,
              onTap: () {
                debugPrint('[ROUTE] tab→Route, routeIds=${controller.routeOrderIds.length}');
                if (!isRouting) controller.toggleRoutingMode();
              },
              icon: Icons.alt_route_rounded,
            ),
            const Spacer(),
            if (isRouting && routeCount > 0)
              GestureDetector(
                onTap: controller.clearRoute,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _tabChip({
    required String label,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : (isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: active ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ── Orders list panel ────────────────────────────────────────────
  Widget _buildOrderListPanel(
      BuildContext context, {
        required bool isDark,
        required List<OrderMapItem> items,
        required String selectedId,
      }) {
    return Obx(() {
      final routeIds = controller.routeOrderIds;
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED)),
        itemBuilder: (_, i) {
          final item = items[i];
          final isSelected = item.order.id == selectedId;
          final inRoute = routeIds.contains(item.order.id);
          return ListTile(
            dense: true,
            selected: isSelected,
            selectedTileColor: isDark ? AppColors.darkSurface2 : const Color(0xFFFFF1F1),
            leading: Icon(
              Icons.location_on,
              color: inRoute ? AppColors.primary : (item.hasCoordinates ? AppColors.textHint : AppColors.textHint),
            ),
            title: Text(
              item.order.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              item.order.subtitle.isEmpty ? AppStrings.mapNoLocationLabel : item.order.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.hasCoordinates)
                  Text(
                    AppStrings.mapNoCoords,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                    ),
                  ),
                if (item.hasCoordinates) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      debugPrint('[ROUTE] tap + on orderId=${item.order.id}, inRoute=$inRoute');
                      if (inRoute) {
                        controller.removeFromRoute(item.order.id);
                      } else {
                        controller.addToRoute(item.order.id);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: inRoute ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: inRoute ? AppColors.primary : (isDark ? AppColors.darkBorder : const Color(0xFFCCCCCC)),
                        ),
                      ),
                      child: Icon(
                        inRoute ? Icons.check : Icons.add,
                        size: 16,
                        color: inRoute ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              controller.focusMapOrder(item.order.id);
              if (!item.hasCoordinates) {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(AppStrings.mapNoCoordSnack)),
                );
              }
            },
          );
        },
      );
    });
  }

// ── Routing panel ────────────────────────────────────────────────
  Widget _buildRoutingPanel(BuildContext context, {required bool isDark}) {
    return Obx(() {
      final routeItems = controller.routeItems;
      if (routeItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route_rounded, size: 36, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
              const SizedBox(height: 8),
              Text(
                'Tap + on any order to build a route',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: controller.toggleRoutingMode,
                child: const Text('Browse Orders'),
              ),
            ],
          ),
        );
      }

      final stats = controller.routeStats;
      final totalKm = stats.totalKm;
      final mins = stats.totalMinutes;
      final timeLabel = mins >= 60
          ? '${mins ~/ 60}h ${mins % 60}m'
          : '${mins}m';

      return Column(
        children: [
          // ── Reorderable stop list ──
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: routeItems.length,
              onReorder: controller.reorderRoute,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                child: child,
              ),
              itemBuilder: (_, i) {
                final item = routeItems[i];
                return ListTile(
                  key: ValueKey(item.order.id),
                  dense: true,
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    item.order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    item.order.subtitle.isEmpty ? AppStrings.mapNoLocationLabel : item.order.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => controller.removeFromRoute(item.order.id),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red.shade400),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.drag_handle,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                      ),
                    ],
                  ),
                  onTap: () => controller.focusMapOrder(item.order.id),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  void _showMapOrderDialog(BuildContext context, OrderModel order) {
    showDialog<void>(
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
                    Expanded(
                      child: Text(
                        order.title,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
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

                // ── Content ──
                FutureBuilder<FsmLocationDialogModel>(
                  future: controller.fetchMapDialogLocationDetails(order.id),
                  builder: (_, snapshot) {
                    final info = snapshot.data ?? FsmLocationDialogModel.empty();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'Phone',
                          value: info.phone,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'Mobile',
                          value: info.mobile,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'Street',
                          value: info.street,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'Street 2',
                          value: info.street2,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'City',
                          value: info.city,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'State',
                          value: info.state,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'Zip',
                          value: info.zip,
                        ),
                        _dialogInfoLine(
                          isDark: isDark,
                          label: 'Country',
                          value: info.country,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Open button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Get.toNamed(AppRoutes.orderCreate,
                          arguments: {'orderId': int.tryParse(order.id)});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child:  Text(
                      AppStrings.mapDialogOpen,
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
  }

  Widget _dialogInfoLine({
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: ${value.trim().isEmpty ? '-' : value}',
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSelectedOrderCard({required bool isDark, required List<OrderMapItem> items}) {
    return Obx(() {
      final id = controller.selectedMapOrderId.value;
      final item = items.where((e) => e.order.id == id).cast<OrderMapItem?>().firstOrNull;
      if (item == null) return const SizedBox.shrink();
      final inRoute = controller.routeOrderIds.contains(id);
      final routeIdx = controller.routeOrderIds.indexOf(id);

      return GestureDetector(
        onTap: () => _showMapOrderDialog(
          Get.context!,
          item.order,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inRoute ? AppColors.primary.withOpacity(0.5) : (isDark ? AppColors.darkBorder : const Color(0xFFEDEDED)),
              width: inRoute ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // Badge
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: inRoute ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: inRoute
                      ? Text('${routeIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))
                      : const Icon(Icons.location_on, size: 17, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.order.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    if (item.order.subtitle.isNotEmpty)
                      Text(
                        item.order.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Open button
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.orderCreate, arguments: {'orderId': int.tryParse(item.order.id)}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 6),
              // Add/Remove route
              if (item.hasCoordinates)
                GestureDetector(
                  onTap: () => inRoute ? controller.removeFromRoute(item.order.id) : controller.addToRoute(item.order.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: inRoute ? Colors.red.withOpacity(0.08) : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: inRoute ? Colors.red.withOpacity(0.25) : AppColors.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(inRoute ? Icons.remove_rounded : Icons.add_rounded, size: 13, color: inRoute ? Colors.red : AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          inRoute ? 'Remove' : 'Route',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inRoute ? Colors.red : AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }


}

