import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/fsm_location_dialog_model.dart';
import '../../../data/models/kanban_board_data.dart';
import '../../../data/models/kanban_column_vm.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/chatter_repository.dart';
import '../../../data/repositories/order_repository.dart';

class OrderController extends GetxController {
  final OrderRepository _repository;

  OrderController(this._repository);

  final orders = <OrderModel>[].obs;
  final kanbanColumns = <KanbanColumnVm>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  /// Header badge counts (wire to real notifications later).
  final messageBadgeCount = 9.obs;
  final historyBadgeCount = 32.obs;
  final selectedOrderView = 'kanban'.obs;
  final isMapLoading = false.obs;
  final mapOrders = <OrderMapItem>[].obs;
  final selectedMapOrderId = ''.obs;
  final selectedCalendarDay = DateTime.now().obs;
  final focusedCalendarDay = DateTime.now().obs;
  Worker? _onlineWorker;
  int _worksheetPrefetchTicket = 0;
  bool _worksheetPrefetchRunning = false;

  final searchQuery        = ''.obs;
  final activeFilters      = <String>{}.obs;
  final activeGroupBy      = ''.obs;

  final isRoutingMode = false.obs;
  final routeOrderIds = <String>[].obs;

  final routePolylinePoints = <LatLng>[].obs;
  final isFetchingRoute = false.obs;
  /// True when polyline is straight-line / cached estimate (no live OSRM).
  final routePolylineIsEstimate = false.obs;
  double _routeDistanceM = 0;
  int _routeDurationS = 0;

  String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1';
  String _osrmProfile = 'driving';
  String _osrmEngineMode = 'osrm';
  bool _routeSyncPending = false;
  final isMapFullscreen = false.obs;
  void toggleMapFullscreen() => isMapFullscreen.toggle();

  @override
  void onReady() {
    super.onReady();
    final connect = Get.find<ConnectivityService>();
    _onlineWorker = ever<bool>(connect.isOnline, (online) async {
      if (online) {
        await _repository.syncPendingOrders();
        if (Get.isRegistered<ChatterRepository>()) {
          await Get.find<ChatterRepository>().syncPendingMessages();
        }
        await loadOrders();
      }
    });
    loadOrders();
  }

  @override
  void onClose() {
    _onlineWorker?.dispose();
    super.onClose();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      AppLogger.debug('loadOrders: starting fetchKanban', tag: 'ORDER_CTRL');
      final data = await _repository.fetchKanban();
      AppLogger.debug(
        'loadOrders: ${data.orders.length} orders, ${data.stages.length} stages',
        tag: 'ORDER_CTRL',
      );
      orders.assignAll(data.orders);
      kanbanColumns.assignAll(
        buildKanbanColumns(data.stages, data.orders),
      );
      orders.refresh();
      kanbanColumns.refresh();
      // Keep first paint fast; worksheet cache warm-up runs in background.
      _prefetchWorksheetsInBackground(data.orders);
      await _loadRoutingConfig();
      await _loadMapOrders(data.orders);
      _warmCachesInBackground(data.orders);
    } catch (e) {
      errorMessage.value = 'Could not load orders.';
      AppLogger.error('loadOrders failed', tag: 'ORDER_CTRL', error: e);
    } finally {
      isLoading.value = false;
    }
  }
  Future<void> _warmCachesInBackground(List<OrderModel> orders) async {
    // Small delay to let UI render first
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _repository.warmOfflineCachesForOrders(orders);
  }

  Future<void> _prefetchWorksheetsInBackground(List<OrderModel> snapshot) async {
    final ticket = ++_worksheetPrefetchTicket;
    if (_worksheetPrefetchRunning) return;
    _worksheetPrefetchRunning = true;
    try {
      // Let the order screen become interactive first.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (ticket != _worksheetPrefetchTicket) return;
      await _repository.prefetchAllWorksheetsForOrders(snapshot);
    } finally {
      _worksheetPrefetchRunning = false;
    }
  }


  void setOrderView(String view) {
    selectedOrderView.value = view;
  }

  Future<void> _loadMapOrders(List<OrderModel> source) async {
    isMapLoading.value = true;
    try {
      final futures = source.map((order) async {
        final id = int.tryParse(order.id);
        if (id == null) return OrderMapItem(order: order);
        final coords = await _repository.fetchOrderMapCoordinates(id);
        return OrderMapItem(
          order: order,
          latitude: coords?.latitude,
          longitude: coords?.longitude,
        );
      }).toList();
      final resolved = await Future.wait(futures);
      mapOrders.assignAll(resolved);
      if (resolved.isNotEmpty) {
        final firstWithCoords = resolved.firstWhereOrNull((e) => e.hasCoordinates);
        selectedMapOrderId.value = firstWithCoords?.order.id ?? resolved.first.order.id;
      } else {
        selectedMapOrderId.value = '';
      }
      await _loadSavedRoute(); // ✅ correct position — after mapOrders is populated
    } catch (e) {
      AppLogger.error('load map orders failed', tag: 'ORDER_CTRL', error: e);
      mapOrders.clear();
      selectedMapOrderId.value = '';
      // ❌ was here before — wrong, only runs on failure
    } finally {
      isMapLoading.value = false;
    }
  }

  void focusMapOrder(String orderId) {
    selectedMapOrderId.value = orderId;
  }

  Future<FsmLocationDialogModel> fetchMapDialogLocationDetails(String orderId) async {
    final id = int.tryParse(orderId);
    if (id == null) return FsmLocationDialogModel.empty();
    return _repository.fetchMapDialogLocationDetails(id);
  }

  void selectCalendarDay(DateTime selected, DateTime focused) {
    selectedCalendarDay.value = DateTime(selected.year, selected.month, selected.day);
    focusedCalendarDay.value = focused;
  }

  int orderCountForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    var count = 0;
    for (final o in orders) {
      final dt = _parseScheduledDate(o.scheduledStart);
      if (dt == null) continue;
      final only = DateTime(dt.year, dt.month, dt.day);
      if (only == d) count++;
    }
    return count;
  }

  List<OrderModel> selectedDayOrders() {
    final d = selectedCalendarDay.value;
    final selected = DateTime(d.year, d.month, d.day);
    return orders.where((o) {
      final dt = _parseScheduledDate(o.scheduledStart);
      if (dt == null) return false;
      final only = DateTime(dt.year, dt.month, dt.day);
      return only == selected;
    }).toList();
  }

  DateTime? _parseScheduledDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final normalized = raw.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
  }




  /// All orders filtered by search + activeFilters
  List<OrderModel> get filteredOrders {
    final q = searchQuery.value.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in7  = today.add(const Duration(days: 7));
    final in30 = today.add(const Duration(days: 30));
    final username = Get.isRegistered<StorageService>()
        ? Get.find<StorageService>().username.toLowerCase()
        : '';

    return orders.where((o) {
      // Search query
      if (q.isNotEmpty) {
        final match = o.title.toLowerCase().contains(q) ||
            o.subtitle.toLowerCase().contains(q) ||
            o.assignedTo.toLowerCase().contains(q);
        if (!match) return false;
      }

      // Filters
      for (final f in activeFilters) {
        switch (f) {
          case 'my_orders':
            if (username.isEmpty) break;
            if (!o.assignedTo.toLowerCase().contains(username)) return false;
            break;
          case 'todo':
            if (o.sectionLabel.toLowerCase() == 'done' ||
                o.sectionLabel.toLowerCase() == 'cancelled') return false;
            break;
          case 'unassigned':
            if (o.assignedTo.isNotEmpty) return false;
            break;
          case 'unscheduled':
            if (o.scheduledStart.isNotEmpty) return false;
            break;
          case 'done':
            if (!o.sectionLabel.toLowerCase().contains('done')) return false;
            break;
          case 'today':
            final dt = _parseScheduledDate(o.scheduledStart);
            if (dt == null) return false;
            final d = DateTime(dt.year, dt.month, dt.day);
            if (d != today) return false;
            break;
          case 'future':
            final dt = _parseScheduledDate(o.scheduledStart);
            if (dt == null) return false;
            if (!dt.isAfter(now)) return false;
            break;
          case 'due_7':
            final dt = _parseScheduledDate(o.scheduledStart);
            if (dt == null) return false;
            final d = DateTime(dt.year, dt.month, dt.day);
            if (d.isBefore(today) || d.isAfter(in7)) return false;
            break;
          case 'due_30':
            final dt = _parseScheduledDate(o.scheduledStart);
            if (dt == null) return false;
            final d = DateTime(dt.year, dt.month, dt.day);
            if (d.isBefore(today) || d.isAfter(in30)) return false;
            break;
        }
      }
      return true;
    }).toList();
  }

  /// Kanban columns built from filteredOrders + groupBy
  List<KanbanColumnVm> get filteredKanbanColumns {
    final filtered = filteredOrders;
    if (activeGroupBy.value == 'assigned_to') {
      final map = <String, List<OrderModel>>{};
      for (final o in filtered) {
        final key = o.assignedTo.isEmpty ? 'Unassigned' : o.assignedTo;
        map.putIfAbsent(key, () => []).add(o);
      }
      return map.entries
          .map((e) {
            final sorted = List<OrderModel>.from(e.value)
              ..sort(OrderModel.compareKanban);
            return KanbanColumnVm(
                title: e.key, orders: sorted, stageId: null);
          })
          .toList();
    }
    // Default: use existing stage-based columns but filter orders
    return kanbanColumns.map((col) {
      final colOrders = filtered.where((o) {
        // Match by stageId when available — title may differ after rename
        if (col.stageId != null && o.stageId != null) {
          return o.stageId == col.stageId;
        }
        return o.sectionLabel == col.title;
      }).toList();
      colOrders.sort(OrderModel.compareKanban);
      return KanbanColumnVm(title: col.title, orders: colOrders, stageId: col.stageId, folded: col.folded);
    }).toList();
  }

  void toggleFilter(String filter) {
    if (activeFilters.contains(filter)) {
      activeFilters.remove(filter);
    } else {
      activeFilters.add(filter);
    }
    activeFilters.refresh();
  }

  void setGroupBy(String groupBy) {
    activeGroupBy.value = activeGroupBy.value == groupBy ? '' : groupBy;
  }

  void clearAllFilters() {
    activeFilters.clear();
    activeGroupBy.value = '';
    searchQuery.value = '';
  }

  Future<void> addStage(String name) async {
    final ok = await _repository.createStage(name);
    if (ok) await loadOrders();
  }

  Future<void> editStage(int stageId, String newName) async {
    // Optimistic update — rename immediately in UI
    final updated = kanbanColumns.map((col) {
      if (col.stageId == stageId) {
        return KanbanColumnVm(
          title: newName,
          orders: col.orders,
          stageId: col.stageId,
          folded: col.folded,
        );
      }
      return col;
    }).toList();
    kanbanColumns.assignAll(updated);
    kanbanColumns.refresh();

    // Persist to Odoo
    final ok = await _repository.updateStageName(stageId, newName);
    if (!ok) await loadOrders(); // revert on failure
  }

  Future<void> removeStage(int stageId) async {
    final ok = await _repository.deleteStage(stageId);
    if (ok) await loadOrders();
  }

  Future<void> toggleFoldStage(int stageId, bool currentlyFolded) async {
    // Optimistic update
    final updated = kanbanColumns.map((col) {
      if (col.stageId == stageId) {
        return KanbanColumnVm(
          title: col.title,
          orders: col.orders,
          stageId: col.stageId,
          folded: !currentlyFolded,
        );
      }
      return col;
    }).toList();
    kanbanColumns.assignAll(updated);
    kanbanColumns.refresh();

    final ok = await _repository.foldStage(stageId, !currentlyFolded);
    if (!ok) await loadOrders();
  }

  Future<bool> moveOrderToStage({
    required OrderModel order,
    required int? toStageId,
    required int toIndex,
  }) async {
    final orderId = int.tryParse(order.id);
    if (orderId == null || toStageId == null) return false;
    try {
      final sequence = ((toIndex + 1) * 10).clamp(1, 999999);
      await _repository.updateOrder(
        orderId,
        <String, dynamic>{
          'stage_id': toStageId,
          'sequence': sequence,
        },
      );
      await loadOrders();
      return true;
    } catch (e) {
      AppLogger.error('moveOrderToStage failed', tag: 'ORDER_CTRL', error: e);
      return false;
    }
  }

  void toggleRoutingMode() {
    isRoutingMode.toggle();
    debugPrint('[ROUTE] mode=${isRoutingMode.value}, stops=${routeOrderIds.length}');
  }

  List<OrderMapItem> get routeItems {
    final result = routeOrderIds
        .map((id) => mapOrders.firstWhereOrNull((e) => e.order.id == id))
        .whereType<OrderMapItem>()
        .toList();
    debugPrint('[ROUTE] routeItems: ${result.length} resolved from ${routeOrderIds.length} ids');
    return result;
  }

  void addToRoute(String orderId) {
    if (routeOrderIds.contains(orderId)) return;
    routeOrderIds.add(orderId);
    routeOrderIds.refresh();
    fetchRoadRoute();
    _syncRouteToServer();
  }

  void removeFromRoute(String orderId) {
    routeOrderIds.remove(orderId);
    routeOrderIds.refresh();
    fetchRoadRoute();
    _syncRouteToServer();
  }

  void reorderRoute(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final id = routeOrderIds.removeAt(oldIndex);
    routeOrderIds.insert(newIndex, id);
    routeOrderIds.refresh();
    fetchRoadRoute();
    _syncRouteToServer();
  }

  void clearRoute() {
    routeOrderIds.clear();
    routePolylinePoints.clear();
    routePolylineIsEstimate.value = false;
    _routeDistanceM = 0;
    _routeDurationS = 0;
    _syncRouteToServer();
  }

  bool get _hasNetworkForRouting {
    if (!Get.isRegistered<ConnectivityService>()) return true;
    return Get.find<ConnectivityService>().hasConnection;
  }

  String _routeGeometryCacheKey(List<OrderMapItem> items) {
    return items.map((e) => e.order.id).join('|');
  }


  /// Haversine straight-line estimate — replace with real routing response when backend ready.
  ({double totalKm, int totalMinutes}) get routeStats {
    // Use real OSRM data when available
    if (_routeDistanceM > 0) {
      return (
      totalKm: _routeDistanceM / 1000,
      totalMinutes: (_routeDurationS / 60).round(),
      );
    }
    // Fallback haversine while OSRM is loading
    final items = routeItems;
    if (items.length < 2) return (totalKm: 0.0, totalMinutes: 0);
    double km = 0;
    for (int i = 0; i < items.length - 1; i++) {
      final a = items[i];
      final b = items[i + 1];
      if (a.hasCoordinates && b.hasCoordinates) {
        km += _haversineKm(a.latitude!, a.longitude!, b.latitude!, b.longitude!);
      }
    }
    return (totalKm: km, totalMinutes: (km / 30 * 60).round());
  }

  /// Fetches a road route from OSRM when online; offline uses cached geometry or straight lines.
  Future<void> fetchRoadRoute() async {
    final items = routeItems.where((e) => e.hasCoordinates).toList();
    if (items.length < 2) {
      routePolylinePoints.clear();
      routePolylineIsEstimate.value = false;
      _routeDistanceM = 0;
      _routeDurationS = 0;
      return;
    }

    final cacheKey = _routeGeometryCacheKey(items);

    if (!_hasNetworkForRouting) {
      final restored = await _restoreRouteGeometryFromCache(cacheKey, items);
      if (!restored) {
        _applyStraightLineRoute(items, isEstimate: true);
      }
      return;
    }

    isFetchingRoute.value = true;
    try {
      final coords = items.map((e) => '${e.longitude},${e.latitude}').join(';');
      final uri = Uri.parse(
        '$_osrmBaseUrl/$_osrmProfile/$coords?overview=full&geometries=geojson',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes == null || routes.isEmpty) throw Exception('No routes returned');

        final route = routes.first as Map<String, dynamic>;
        _routeDistanceM = (route['distance'] as num).toDouble();
        _routeDurationS = (route['duration'] as num).toInt();

        final rawCoords = (route['geometry'] as Map)['coordinates'] as List;
        final points = rawCoords
            .map((c) {
          final pair = c as List;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        })
            .where((ll) => ll.latitude.isFinite && ll.longitude.isFinite)
            .toList();

        routePolylinePoints.assignAll(points);
        routePolylineIsEstimate.value = false;
        await _repository.saveRouteGeometryCache(
          cacheKey: cacheKey,
          points: points
              .map((p) => <String, double>{'lat': p.latitude, 'lng': p.longitude})
              .toList(),
          distanceM: _routeDistanceM,
          durationS: _routeDurationS,
        );
        debugPrint(
          '[ROUTE] OSRM: ${points.length} pts, '
              '${(_routeDistanceM / 1000).toStringAsFixed(1)} km, '
              '${_routeDurationS}s',
        );
      } else {
        throw Exception('OSRM status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ROUTE] OSRM failed ($e) → cache or straight-line');
      final restored = await _restoreRouteGeometryFromCache(cacheKey, items);
      if (!restored) {
        _applyStraightLineRoute(items, isEstimate: true);
      }
    } finally {
      isFetchingRoute.value = false;
    }
  }

  void _applyStraightLineRoute(List<OrderMapItem> items, {required bool isEstimate}) {
    routePolylinePoints.assignAll(
      items.map((item) => LatLng(item.latitude!, item.longitude!)).toList(),
    );
    routePolylineIsEstimate.value = isEstimate;
    _routeDistanceM = 0;
    _routeDurationS = 0;
  }

  Future<bool> _restoreRouteGeometryFromCache(
    String cacheKey,
    List<OrderMapItem> items,
  ) async {
    final cached = await _repository.readRouteGeometryCache(cacheKey);
    if (cached == null) return false;
    final rawPts = cached['points'];
    if (rawPts is! List || rawPts.isEmpty) return false;

    final points = <LatLng>[];
    for (final p in rawPts) {
      if (p is! Map) continue;
      final m = Map<String, dynamic>.from(p);
      final lat = m['lat'] is num
          ? (m['lat'] as num).toDouble()
          : double.tryParse('${m['lat']}');
      final lng = m['lng'] is num
          ? (m['lng'] as num).toDouble()
          : double.tryParse('${m['lng']}');
      if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) continue;
      points.add(LatLng(lat, lng));
    }
    if (points.length < 2) return false;

    routePolylinePoints.assignAll(points);
    routePolylineIsEstimate.value = true;
    _routeDistanceM = (cached['distance_m'] as num?)?.toDouble() ?? 0;
    _routeDurationS = (cached['duration_s'] as num?)?.toInt() ?? 0;
    return true;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  Future<void> _loadRoutingConfig() async {
    final config = await _repository.fetchRoutingConfig();
    _osrmBaseUrl = config['osrm_base_url']!;
    _osrmProfile = config['profile']!;
    _osrmEngineMode = config['engine_mode']!;
    debugPrint('[ROUTE] config: $_osrmBaseUrl | profile=$_osrmProfile');
  }

  Future<void> _loadSavedRoute() async {
    try {
      final payload = await _repository.fetchSavedRoute();
      if (payload == null) {
        debugPrint('[ROUTE] no saved route on server');
        return;
      }
      final orders = payload['orders'] as List?;
      if (orders == null || orders.isEmpty) return;

      debugPrint('[ROUTE] restoring ${orders.length} stops from server');

      // Re-map fsm_id → local order id string
      final ids = orders
          .map((o) => (o as Map)['fsm_id']?.toString())
          .whereType<String>()
          .toList();

      // Only restore ids that exist in loaded mapOrders
      final validIds = ids
          .where((id) => mapOrders.any((e) => e.order.id == id))
          .toList();

      if (validIds.isEmpty) return;

      routeOrderIds.assignAll(validIds);
      routeOrderIds.refresh();
      await fetchRoadRoute();
    } catch (e) {
      AppLogger.error('_loadSavedRoute failed', tag: 'ORDER_CTRL', error: e);
    }
  }

  Future<void> _syncRouteToServer() async {
    if (_routeSyncPending) return;
    _routeSyncPending = true;
    // Debounce: wait for rapid add/remove/reorder to settle
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _routeSyncPending = false;

    final items = routeItems;
    final orders = items.asMap().entries.map((e) {
      final item = e.value;
      return {
        'fsm_id': int.tryParse(item.order.id) ?? 0,
        'sequence': e.key + 1,
        'displayName': item.order.title,
        'lat': item.latitude,
        'lng': item.longitude,
      };
    }).toList();
    final ok = await _repository.saveRoute(
      orders: orders,
      engineMode: _osrmEngineMode,
      profile: _osrmProfile,
    );
    debugPrint('[ROUTE] sync to server: ${ok ? "ok" : "failed"} (${orders.length} stops)');
  }

}

class OrderMapItem {
  const OrderMapItem({
    required this.order,
    this.latitude,
    this.longitude,
  });

  final OrderModel order;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      latitude != null && longitude != null &&
          latitude!.isFinite && longitude!.isFinite;
}
